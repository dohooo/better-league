import Foundation

/// AWDL (AirDrop, Handoff) and Wi-Fi Aware share the Wi-Fi radio and leave the access point's
/// channel every half second while their interfaces are up. Lowering them needs root, so the app
/// runs ifconfig through a sudoers rule installed once with administrator approval.
enum PeerToPeerRadio {
    static let interfaces = ["awdl0", "nan0"]
    private static let ifconfig = "/sbin/ifconfig"
    private static let sudo = "/usr/bin/sudo"
    private static let rulePath = "/etc/sudoers.d/better-league"

    static func isUp(_ interface: String) -> Bool {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return false }
        defer { freeifaddrs(list) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next })
        where String(cString: entry.pointee.ifa_name) == interface {
            return entry.pointee.ifa_flags & UInt32(IFF_UP) != 0
        }
        return false
    }

    static func isAuthorized() -> Bool {
        run(sudo, ["-n", "-l", ifconfig, interfaces[0], "down"]).status == 0
    }

    static func set(_ interface: String, up: Bool) throws {
        let result = run(sudo, ["-n", ifconfig, interface, up ? "up" : "down"])
        guard result.status == 0 else {
            throw GuardError.unavailable(result.output.isEmpty ? "ifconfig \(interface) exited with \(result.status)." : result.output)
        }
    }

    /// Writes a sudoers rule that lets the current user raise and lower the two interfaces without a password.
    static func installHelper() throws {
        let commands = interfaces.flatMap { ["\(ifconfig) \($0) down", "\(ifconfig) \($0) up"] }
        let rule = "\(NSUserName()) ALL=(root) NOPASSWD: \(commands.joined(separator: ", "))\n"
        let draft = FileManager.default.temporaryDirectory.appendingPathComponent("better-league-sudoers-\(getpid())")
        try rule.write(to: draft, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: draft) }
        let shell = "/usr/sbin/visudo -cf '\(draft.path)' && /usr/bin/install -m 0440 -o root -g wheel '\(draft.path)' '\(rulePath)'"
        let quoted = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(quoted)\" with administrator privileges")?.executeAndReturnError(&error)
        if let error {
            if error[NSAppleScript.errorNumber] as? Int == -128 {
                throw GuardError.unavailable("Authorization was cancelled.")
            }
            throw GuardError.unavailable(error[NSAppleScript.errorMessage] as? String ?? "Could not install the network helper.")
        }
    }

    private static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

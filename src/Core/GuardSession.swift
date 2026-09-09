import Foundation

enum GuardError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let message): return message }
    }
}

/// One recovery engine per user, shared by the app and the command-line tool.
@MainActor
final class GuardSession {
    private var descriptor: Int32 = -1
    private var engine: CursorGuard?

    func start(onStatusChange: @escaping (String) -> Void) throws {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Better League", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        descriptor = open(directory.appendingPathComponent("guard.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            throw GuardError.unavailable("Could not open the recovery lock file.")
        }
        do {
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
                throw GuardError.unavailable("Another Better League instance is already running.")
            }
            // Older command-line builds do not use the shared lock.
            let probe = Process()
            let output = Pipe()
            probe.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            probe.arguments = ["-u", String(getuid()), "-x", "lolrestore"]
            probe.standardOutput = output
            try probe.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            probe.waitUntilExit()
            let pids = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isWhitespace).compactMap { Int32($0) }
            guard !pids.contains(where: { $0 != getpid() }) else {
                throw GuardError.unavailable("A command-line guard is running. Run ‘lol stop’ first.")
            }
            let guardEngine = CursorGuard(logger: try GuardLog())
            guardEngine.onStatusChange = onStatusChange
            try guardEngine.start()
            engine = guardEngine
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        if descriptor >= 0 {
            close(descriptor)
            descriptor = -1
        }
    }
}

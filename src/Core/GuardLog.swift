import Foundation

final class GuardLog {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/better-league", isDirectory: true)
    private let url = directory.appendingPathComponent("lolrestore.log")
    private let formatter = DateFormatter()
    private let maxBytes = Int(ProcessInfo.processInfo.environment["LOLRESTORE_MAXLOG"] ?? "") ?? 3 * 1024 * 1024
    private var handle: FileHandle?
    private var bytes = 0

    init() throws {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try open()
    }

    private func open() throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: url)
        bytes = Int(try handle!.seekToEnd())
    }

    func write(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)
        do {
            try handle?.write(contentsOf: data)
            bytes += data.count
            if bytes > maxBytes {
                try handle?.close()
                let old = url.appendingPathExtension("old")
                if FileManager.default.fileExists(atPath: old.path) {
                    try FileManager.default.removeItem(at: old)
                }
                try FileManager.default.moveItem(at: url, to: old)
                try open()
            }
        } catch {
            fputs("Log write failed: \(error.localizedDescription)\n", stderr)
        }
        print(line, terminator: "")
        fflush(stdout)
    }

    deinit { try? handle?.close() }
}

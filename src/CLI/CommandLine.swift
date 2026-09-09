import ApplicationServices
import Foundation

@main
struct CommandLineTool {
    @MainActor
    static func main() {
        if !AXIsProcessTrusted(), isatty(fileno(stdin)) != 0 {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        let session = GuardSession()
        do {
            try session.start { print($0) }
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
        if let seconds = Double(ProcessInfo.processInfo.environment["LOLRESTORE_SECONDS"] ?? "") {
            Timer.scheduledTimer(withTimeInterval: max(0.01, seconds), repeats: false) { _ in
                MainActor.assumeIsolated {
                    session.stop()
                    exit(0)
                }
            }
        }
        RunLoop.main.run()
    }
}

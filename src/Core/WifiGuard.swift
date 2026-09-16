import AppKit

/// Lowers the peer-to-peer Wi-Fi interfaces while a League match runs and raises them afterwards.
@MainActor
final class WifiGuard {
    private static let loweredKey = "loweredInterfaces"
    private let logger: GuardLog
    private var timer: Timer?
    private var inMatch = false
    var onStatusChange: ((String) -> Void)?

    /// Interfaces this app lowered, kept in defaults so a crash does not leave them down for good.
    private var lowered: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.loweredKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.loweredKey) }
    }

    init(logger: GuardLog) { self.logger = logger }

    func start() throws {
        guard PeerToPeerRadio.isAuthorized() else {
            throw GuardError.unavailable("Authorize the network helper to turn on low-latency Wi-Fi.")
        }
        logger.write("Started; checking for a match every 2 s")
        poll()
        publishStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        inMatch = false
        raise()
        logger.write("Stopped")
    }

    private func publishStatus() {
        onStatusChange?(inMatch ? "AirDrop radio is off until the match ends" : "Waiting for a match")
    }

    private func poll() {
        let running = leagueGameIsRunning()
        if running != inMatch {
            inMatch = running
            logger.write(running ? "Match detected; lowering peer-to-peer Wi-Fi" : "Match ended; restoring peer-to-peer Wi-Fi")
            publishStatus()
        }
        if running { lower() } else { raise() }
    }

    /// Runs on every poll during a match because macOS raises awdl0 again on its own.
    private func lower() {
        for interface in PeerToPeerRadio.interfaces where PeerToPeerRadio.isUp(interface) {
            do {
                try PeerToPeerRadio.set(interface, up: false)
                if !lowered.contains(interface) { lowered += [interface] }
                logger.write("\(interface) down")
            } catch {
                logger.write("\(interface) down failed: \(error.localizedDescription)")
                onStatusChange?(error.localizedDescription)
            }
        }
    }

    private func raise() {
        for interface in lowered {
            do {
                try PeerToPeerRadio.set(interface, up: true)
                logger.write("\(interface) up")
            } catch {
                logger.write("\(interface) up failed: \(error.localizedDescription)")
            }
        }
        lowered = []
    }
}

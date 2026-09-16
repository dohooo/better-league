import Combine
import Foundation

@MainActor
final class WifiModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Low-latency Wi-Fi is off"
    @Published private(set) var needsHelper = false
    private var engine: WifiGuard?
    private let defaults = UserDefaults.standard

    func restorePreference() {
        if defaults.bool(forKey: "lowLatencyWifiEnabled") { setEnabled(true) }
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            stop()
            defaults.set(false, forKey: "lowLatencyWifiEnabled")
            status = "Low-latency Wi-Fi is off"
            needsHelper = false
            return
        }
        guard !isEnabled else { return }
        guard PeerToPeerRadio.isAuthorized() else {
            needsHelper = true
            status = "Authorize the network helper to turn this on."
            return
        }
        needsHelper = false
        do {
            let next = WifiGuard(logger: try GuardLog(filename: "wifi.log"))
            next.onStatusChange = { [weak self] text in self?.status = text }
            try next.start()
            engine = next
            isEnabled = true
            defaults.set(true, forKey: "lowLatencyWifiEnabled")
        } catch {
            status = error.localizedDescription
        }
    }

    func installHelper() {
        do {
            try PeerToPeerRadio.installHelper()
            setEnabled(true)
        } catch {
            status = error.localizedDescription
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        isEnabled = false
    }
}

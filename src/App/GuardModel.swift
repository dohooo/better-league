import AppKit
import ApplicationServices
import Combine

@MainActor
final class GuardModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Recovery is off"
    @Published private(set) var needsAccessibility = false
    private var session: GuardSession?
    private var permissionTimer: Timer?
    private var healthTimer: Timer?
    private let defaults = UserDefaults.standard

    func restorePreference() {
        if defaults.bool(forKey: "recoveryEnabled") { setEnabled(true) }
    }

    func setEnabled(_ enabled: Bool) {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if !enabled {
            stop()
            defaults.set(false, forKey: "recoveryEnabled")
            status = "Recovery is off"
            needsAccessibility = false
            return
        }
        guard !isEnabled else { return }
        guard AXIsProcessTrusted() else {
            needsAccessibility = true
            status = "Allow Accessibility to turn on recovery."
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    if AXIsProcessTrusted() { self?.setEnabled(true) }
                }
            }
            return
        }
        needsAccessibility = false
        let next = GuardSession()
        do {
            try next.start { [weak self] text in self?.status = text }
            session = next
            isEnabled = true
            defaults.set(true, forKey: "recoveryEnabled")
            healthTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !AXIsProcessTrusted() else { return }
                    self.setEnabled(false)
                    self.needsAccessibility = true
                    self.status = "Accessibility access was removed."
                }
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        healthTimer?.invalidate()
        healthTimer = nil
        session?.stop()
        session = nil
        isEnabled = false
    }
}

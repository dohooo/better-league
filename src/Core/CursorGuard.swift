import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class CursorGuard {
    private let gameBundleID = "com.riotgames.LeagueofLegends.GameClient"
    private let attackMoveKey: CGKeyCode = 0 // Physical A key: attack-move targeting.
    // ---------- state ----------
    private var engaged = false
    private var captureMode = false
    private var seenBig = false
    private struct Incident { let t0: Date; var injections: Int; var nextActionAt: Date; var hiddenSince: Date? }
    private var incident: Incident?
    private var cooldownUntil = Date.distantPast
    private var consecutiveGiveups = 0
    private var lastSeed: Int32 = -1
    private var lastClass = CursorClass.none
    private var lastDesc = "none"
    private var reclassifyUntil = Date.distantPast
    private var tick = 0
    private var timer: Timer?
    private let logger: GuardLog
    var onStatusChange: ((String) -> Void)?
    private let desktopMaxWidth = (NSScreen.screens.map { $0.frame.width }.max() ?? 2000) + 100


    init(logger: GuardLog) { self.logger = logger }

    func start() throws {
        guard cursorAPIsAvailable() else {
            throw GuardError.unavailable("Cursor detection is unavailable on this version of macOS.")
        }
        guard AXIsProcessTrusted() else {
            throw GuardError.unavailable("Allow Accessibility access before enabling cursor recovery.")
        }
        log("Started; checking cursor changes at 240 Hz")
        publishStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 240.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        log("Stopped")
    }

    private func log(_ message: String) { logger.write(message) }

    private func publishStatus() {
        onStatusChange?(engaged ? (captureMode ? "Watching your cursor" : "Waiting for full-screen play") : "Waiting for a match")
    }

    private func gameApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == gameBundleID }
    }
    private func mousePos() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }

    private func injectAttackMoveKey() {
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: attackMoveKey, keyDown: true)?.post(tap: .cghidEventTap)
        usleep(20_000)
        CGEvent(keyboardEventSource: src, virtualKey: attackMoveKey, keyDown: false)?.post(tap: .cghidEventTap)
    }

    private func poll() {
        tick += 1
        let now = Date()

        if tick % 480 == 0 { // ~2s process poll
            let running = gameApp() != nil
            if running != engaged {
                engaged = running
                incident = nil
                seenBig = false
                consecutiveGiveups = 0
                log(engaged ? "Match detected; recovery is active" : "Match ended; waiting for a match")
                publishStatus()
            }
        }
        guard engaged else { return }

        // key injection is armed ONLY while the game owns the display
        if tick % 24 == 0 { // ~10Hz
            let inCapture = CGDisplayBounds(CGMainDisplayID()).width >= desktopMaxWidth
            if inCapture != captureMode {
                captureMode = inCapture
                incident = nil
                log(captureMode ? "Entered full-screen capture space" : "Left full-screen capture space")
                publishStatus()
            }
        }

        // -- detection: classify on seed change, and keep re-classifying for 50ms
        //    after each change (and during incidents) so we never race the update
        let seed = currentCursorSeed()
        if seed != lastSeed {
            lastSeed = seed
            reclassifyUntil = now.addingTimeInterval(0.05)
        }
        if now < reclassifyUntil || incident != nil {
            let r = classifyCursor()
            lastClass = r.cls
            lastDesc = r.desc
        }

        guard captureMode else { return }

        if lastClass == .big && !seenBig {
            seenBig = true
            log("First large cursor seen (\(lastDesc)); recovery armed")
        }

        // -- incident FSM
        if var inc = incident {
            if lastClass == .big {
                log("RESTORED sprite=\(lastDesc) elapsed=\(Int(now.timeIntervalSince(inc.t0) * 1000))ms A_presses=\(inc.injections)")
                incident = nil
                consecutiveGiveups = 0
            } else if lastClass == .none {
                if let h = inc.hiddenSince {
                    if now.timeIntervalSince(h) > 1.0 {
                        log("HIDDEN cursor unavailable; elapsed=\(Int(now.timeIntervalSince(inc.t0) * 1000))ms")
                        incident = nil
                    }
                } else {
                    inc.hiddenSince = now
                    incident = inc
                }
            } else if now.timeIntervalSince(inc.t0) > 3.0 {
                consecutiveGiveups += 1
                let cd = min(30.0, pow(2.0, Double(consecutiveGiveups)))
                cooldownUntil = now.addingTimeInterval(cd)
                log("GIVEUP cursor remains small; A_presses=\(inc.injections) cooldown=\(Int(cd))s consecutive=\(consecutiveGiveups)")
                incident = nil
            } else {
                if lastClass == .small { inc.hiddenSince = nil }
                if now >= inc.nextActionAt && inc.injections < 2 {
                    inc.injections += 1
                    inc.nextActionAt = now.addingTimeInterval(0.45)
                    injectAttackMoveKey()
                    log("ACTION A_press=\(inc.injections)")
                }
                incident = inc
            }
        } else if lastClass == .small && seenBig && now >= cooldownUntil {
            let p = mousePos()
            incident = Incident(t0: now, injections: 1, nextActionAt: now.addingTimeInterval(0.45), hiddenSince: nil)
            injectAttackMoveKey()
            log("FLIP -> \(lastDesc) pos=(\(Int(p.x)),\(Int(p.y))) A_press=1")
        }
    }
}

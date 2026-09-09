import AppKit
import Combine
import SwiftUI

@main
struct BetterLeagueApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let model = GuardModel()
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var recoveryItem: NSMenuItem!
    private var windowItem: NSMenuItem!
    private var subscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first(where: { $0.processIdentifier != getpid() }) {
            NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: .init())
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        window = RecoveryWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Better League"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        let mainMenu = NSMenu()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "Quit Better League", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let applicationItem = NSMenuItem()
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        let windowMenu = NSMenu(title: "Window")
        let closeWindow = windowMenu.addItem(withTitle: "Close Window", action: #selector(hideWindow), keyEquivalent: "w")
        closeWindow.target = self
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.mainMenu = mainMenu
        let content = NSHostingView(rootView: ControlView(model: model))
        window.contentView = content
        window.setContentSize(content.fittingSize)
        window.center()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.setAccessibilityLabel("Better League")
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Better League", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        recoveryItem = NSMenuItem(title: "Cursor Recovery", action: #selector(toggleRecovery), keyEquivalent: "")
        recoveryItem.target = self
        menu.addItem(recoveryItem)
        menu.addItem(.separator())
        windowItem = NSMenuItem(title: "Hide Window", action: #selector(toggleWindow), keyEquivalent: "")
        windowItem.target = self
        menu.addItem(windowItem)
        let quit = NSMenuItem(title: "Quit Better League", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        subscription = model.$isEnabled.sink { [weak self] enabled in
            self?.updateStatusItem(enabled: enabled)
        }
        showWindow()
        model.restorePreference()
    }

    private func updateStatusItem(enabled: Bool) {
        let image = NSImage(systemSymbolName: enabled ? "cursorarrow.rays" : "cursorarrow", accessibilityDescription: "Better League")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Better League — Recovery \(enabled ? "On" : "Off")"
        recoveryItem.state = enabled ? .on : .off
    }

    func menuWillOpen(_ menu: NSMenu) {
        windowItem.title = window.isVisible ? "Hide Window" : "Show Window"
    }

    private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleRecovery() {
        let enabling = !model.isEnabled
        model.setEnabled(enabling)
        if enabling && !model.isEnabled { showWindow() }
    }

    @objc private func toggleWindow() {
        if window.isVisible { hideWindow() } else { showWindow() }
    }

    @objc private func hideWindow() { window.orderOut(nil) }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}

private final class RecoveryWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}

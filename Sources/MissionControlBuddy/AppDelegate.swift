import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let enhancer = MissionControlEnhancer()
    private let preferencesController = PreferencesWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureAccessibilityPermission()

        preferencesController.overlayEnabledProvider = { [weak self] in
            self?.enhancer.isEnabled ?? true
        }
        preferencesController.setOverlayEnabled = { [weak self] enabled in
            guard let self else { return }
            self.enhancer.setEnabled(enabled)
            self.statusBarController?.rebuildMenu()
        }
        preferencesController.menuIconVisibilityChanged = { [weak self] visible in
            self?.statusBarController?.isVisible = visible
        }
        preferencesController.quitHandler = {
            NSApp.terminate(nil)
        }

        statusBarController = StatusBarController(enhancer: enhancer) { [weak self] in
            self?.preferencesController.showAndFocus()
        }
        statusBarController?.isVisible = PreferencesStore.shared.showMenuBarIcon

        enhancer.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: PreferencesStore.changedNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        enhancer.stop()
        statusBarController = nil
    }

    /// If the menu bar icon is hidden, relaunching/opening the app should bring
    /// preferences so users still have a control surface.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !PreferencesStore.shared.showMenuBarIcon {
            preferencesController.showAndFocus()
            return false
        }
        return true
    }

    @objc private func preferencesChanged() {
        statusBarController?.isVisible = PreferencesStore.shared.showMenuBarIcon
        statusBarController?.rebuildMenu()
    }

    /// Prompts for Accessibility permission if not already granted. The Dock AX
    /// tree (where Mission Control thumbnails live) is unreadable without it.
    private func ensureAccessibilityPermission() {
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility permission needed"
            alert.informativeText = """
            MissionControlBuddy needs Accessibility access to read Mission Control \
            thumbnails.

            Open System Settings → Privacy & Security → Accessibility, enable this \
            app (or your terminal if running via 'swift run'), then relaunch.
            """
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

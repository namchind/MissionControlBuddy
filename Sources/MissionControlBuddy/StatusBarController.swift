import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let enhancer: MissionControlEnhancer
    private lazy var preferencesController = PreferencesWindowController()

    init(enhancer: MissionControlEnhancer) {
        self.enhancer = enhancer
        super.init()
        setupStatusBarButton()
    }

    private func setupStatusBarButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "rectangle.3.group.bubble.left", accessibilityDescription: "Mission Control Buddy")
        button.image?.isTemplate = true
        button.toolTip = "Mission Control Buddy — enhances native Mission Control"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggleTitle = enhancer.isEnabled ? "Disable Overlays" : "Enable Overlays"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let statusLabel = NSMenuItem(
            title: enhancer.isEnabled ? "Status: watching Mission Control" : "Status: paused",
            action: nil,
            keyEquivalent: ""
        )
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit MissionControlBuddy", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        enhancer.setEnabled(!enhancer.isEnabled)
        rebuildMenu()
    }

    @objc private func showPreferences() {
        preferencesController.showAndFocus()
    }

    @objc private func toggleLaunchAtLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        rebuildMenu()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Mission Control Buddy"
        alert.informativeText = """
        Enhances the native macOS Mission Control (Control+Up / swipe up) by \
        overlaying each window thumbnail with its app icon, app name, and window title.

        Requires Accessibility permission (System Settings → Privacy & Security → Accessibility).
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let enhancer: MissionControlEnhancer

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

        let statusItemLabel = NSMenuItem(
            title: enhancer.isEnabled ? "Status: watching Mission Control" : "Status: paused",
            action: nil,
            keyEquivalent: ""
        )
        statusItemLabel.isEnabled = false
        menu.addItem(statusItemLabel)

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

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Mission Control Buddy"
        alert.informativeText = """
        Enhances the native macOS Mission Control (Control+Up / swipe up) by \
        overlaying each window thumbnail with its app icon, app name, and window title.

        Requires Accessibility permission (System Settings → Privacy & Security → Accessibility).

        Note: this relies on the Dock's Accessibility tree and floats overlays at a \
        high window level. It's experimental and may need tweaks across macOS versions.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

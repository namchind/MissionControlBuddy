import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let enhancer = MissionControlEnhancer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureAccessibilityPermission()
        statusBarController = StatusBarController(enhancer: enhancer)
        enhancer.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        enhancer.stop()
        statusBarController = nil
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

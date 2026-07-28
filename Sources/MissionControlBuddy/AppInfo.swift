import AppKit

/// Central place for app identity + the shared About panel, so the menu bar
/// "About" and the Preferences "About" button stay perfectly in sync (DRY).
@MainActor
enum AppInfo {

    /// Marketing version. Reads `CFBundleShortVersionString` from the bundle
    /// (single source of truth in Info.plist); falls back to this constant when
    /// running the bare binary via `swift run`, so a version always shows.
    static let fallbackVersion = "1.0.1"

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let value = (short?.isEmpty == false) ? short! : fallbackVersion
        return value
    }

    static var displayName: String { "Mission Control Buddy" }

    /// The app icon, loaded from the bundle's AppIcon resource. Accessory
    /// (LSUIElement) apps don't get one set automatically, so we load it
    /// explicitly and reuse it for the app icon, About panel, and Preferences.
    static var icon: NSImage? {
        if let named = NSImage(named: "AppIcon") { return named }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    /// Shows the shared About dialog. Called from both the status-bar menu and
    /// the Preferences window.
    static func presentAbout() {
        let alert = NSAlert()
        alert.messageText = "\(displayName)  •  v\(version)"
        alert.informativeText = """
        Enhances the native macOS Mission Control (Control+Up / three finger swipe up) by \
        overlaying each window thumbnail with its app icon, app name, and window title.

        Requires Accessibility permission (System Settings → Privacy & Security → Accessibility).
        """
        if let icon { alert.icon = icon }
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

import AppKit
import ApplicationServices

/// Resolves a Mission Control thumbnail title to its owning app's icon + name.
///
/// Strategy: enumerate regular running apps, and for each, read its window
/// titles via the Accessibility API. Build a `windowTitle -> app` map. This
/// avoids needing Screen Recording permission (which kCGWindowName requires).
struct IconResolver {

    struct Resolved {
        let appName: String
        let icon: NSImage?
    }

    private var titleToApp: [String: NSRunningApplication] = [:]
    private var appNameToApp: [String: NSRunningApplication] = [:]

    /// Rebuild the lookup. Call this each time Mission Control opens so the
    /// map reflects the current set of windows.
    mutating func refresh() {
        titleToApp.removeAll(keepingCapacity: true)
        appNameToApp.removeAll(keepingCapacity: true)

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in apps {
            if let name = app.localizedName {
                appNameToApp[name] = app
            }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = DockAXReader.copyAttribute(axApp, kAXWindowsAttribute as String) as? [AXUIElement] else {
                continue
            }

            for window in windows {
                let title = DockAXReader.title(window)
                if !title.isEmpty {
                    titleToApp[title] = app
                }
            }
        }
    }

    /// Resolve a thumbnail title to an app icon + name.
    func resolve(title: String) -> Resolved {
        // 1. Exact window-title match.
        if let app = titleToApp[title] {
            return Resolved(appName: app.localizedName ?? title, icon: app.icon)
        }

        // 2. Title often looks like "file — AppName" or "file – AppName".
        //    Try matching the trailing segment against known app names.
        for separator in [" — ", " – ", " - "] {
            if let range = title.range(of: separator, options: .backwards) {
                let tail = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if let app = appNameToApp[tail] {
                    return Resolved(appName: app.localizedName ?? tail, icon: app.icon)
                }
                let head = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if let app = appNameToApp[head] {
                    return Resolved(appName: app.localizedName ?? head, icon: app.icon)
                }
            }
        }

        // 3. Whole title equals an app name (e.g. "Calendar", "Postman").
        if let app = appNameToApp[title] {
            return Resolved(appName: app.localizedName ?? title, icon: app.icon)
        }

        // 4. Substring fallback: any app name contained in the title.
        for (name, app) in appNameToApp where title.localizedCaseInsensitiveContains(name) {
            return Resolved(appName: name, icon: app.icon)
        }

        // 5. Give up on the icon, keep the title as the name.
        return Resolved(appName: title, icon: nil)
    }
}

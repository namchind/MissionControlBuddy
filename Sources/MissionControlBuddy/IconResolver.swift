import AppKit
import ApplicationServices

/// Resolves a Mission Control thumbnail title to its owning app's icon + name.
///
/// Mission Control exposes NO app identity on its thumbnail buttons (proven by
/// MissionControlAttrProbe — only title/frame/role are available). So we match
/// the thumbnail's window title against the real per-app AX window titles.
///
/// Key gotcha: Mission Control MIDDLE-TRUNCATES long titles with an ellipsis
/// (e.g. "…spaces i…n Mac…"). Exact matching fails for those, so we also do a
/// prefix/suffix match around the ellipsis.
struct IconResolver {

    struct Resolved {
        let appName: String
        let icon: NSImage?
    }

    private struct WindowEntry {
        let title: String
        let app: NSRunningApplication
    }

    private var titleToApp: [String: NSRunningApplication] = [:]
    private var appNameToApp: [String: NSRunningApplication] = [:]
    private var windows: [WindowEntry] = []

    /// The character macOS uses for truncation (U+2026 HORIZONTAL ELLIPSIS).
    private static let ellipsis: Character = "\u{2026}"

    /// Rebuild the lookup. Call this each time Mission Control opens so the
    /// map reflects the current set of windows.
    mutating func refresh() {
        titleToApp.removeAll(keepingCapacity: true)
        appNameToApp.removeAll(keepingCapacity: true)
        windows.removeAll(keepingCapacity: true)

        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in apps {
            if let name = app.localizedName {
                appNameToApp[name] = app
            }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let axWindows = DockAXReader.copyAttribute(axApp, kAXWindowsAttribute as String) as? [AXUIElement] else {
                continue
            }

            for window in axWindows {
                let title = DockAXReader.title(window)
                guard !title.isEmpty else { continue }
                windows.append(WindowEntry(title: title, app: app))
                if titleToApp[title] == nil {
                    titleToApp[title] = app   // keep first mapping; avoid random flips
                }
            }
        }
    }

    /// Resolve a thumbnail title to an app icon + name.
    func resolve(title: String) -> Resolved {
        // 1. Exact window-title match (works for non-truncated titles).
        if let app = titleToApp[title] {
            return resolved(app, fallbackName: title)
        }

        // 2. Middle-ellipsis truncation: match a real window by prefix/suffix.
        if let app = matchTruncated(title) {
            return resolved(app, fallbackName: title)
        }

        // 3. Title of the form "document — AppName": match the trailing segment.
        for separator in [" \u{2014} ", " \u{2013} ", " - "] {
            if let range = title.range(of: separator, options: .backwards) {
                let tail = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if let app = appNameToApp[tail] {
                    return resolved(app, fallbackName: tail)
                }
                let head = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if let app = appNameToApp[head] {
                    return resolved(app, fallbackName: head)
                }
            }
        }

        // 4. Whole title equals an app name (e.g. "Calendar", "Postman").
        if let app = appNameToApp[title] {
            return resolved(app, fallbackName: title)
        }

        // 5. Give up on the icon; keep the title as the name.
        return Resolved(appName: title, icon: nil)
    }

    // MARK: - Helpers

    private func resolved(_ app: NSRunningApplication, fallbackName: String) -> Resolved {
        Resolved(appName: app.localizedName ?? fallbackName, icon: app.icon)
    }

    /// Match a middle-truncated title (containing "\u{2026}") against a real window
    /// title. The prefix (before the ellipsis) must anchor at the START of the
    /// real title; the suffix (after the ellipsis) must appear SOMEWHERE after
    /// it. We use `contains` for the suffix rather than `hasSuffix` because some
    /// apps append extra text to their AX window title that Mission Control's
    /// thumbnail title omits — e.g. Chrome adds " - Google Chrome - <profile>".
    private func matchTruncated(_ truncated: String) -> NSRunningApplication? {
        guard truncated.contains(Self.ellipsis) else { return nil }

        // Split on every ellipsis; the first segment is the prefix, the last is
        // the suffix (handles rare multi-ellipsis titles too).
        let segments = truncated
            .split(separator: Self.ellipsis, omittingEmptySubsequences: false)
            .map(String.init)
        guard let prefix = segments.first, let suffix = segments.last else { return nil }

        // Guard against too-loose matches (very short prefix + suffix).
        guard prefix.count + suffix.count >= 6 else { return nil }

        for entry in windows {
            let realTitle = entry.title
            guard realTitle.count >= prefix.count else { continue }
            if (prefix.isEmpty || realTitle.hasPrefix(prefix)),
               (suffix.isEmpty || realTitle.contains(suffix)) {
                return entry.app
            }
        }
        return nil
    }
}

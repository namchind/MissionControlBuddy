import AppKit
import ApplicationServices

/// A single Mission Control thumbnail as exposed by the Dock's Accessibility tree.
struct Thumbnail {
    let title: String
    /// Frame in AX/global coordinates (top-left origin, y grows downward).
    let axFrame: CGRect
}

/// Reads native Mission Control thumbnails from the Dock process via the
/// public Accessibility API. Probe #2 proved these exist as AXButtons nested
/// under an AXGroup titled "Mission Control".
enum DockAXReader {

    // MARK: - Generic AX helpers

    static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copyAttribute(element, attribute) as? String
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        (copyAttribute(element, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
    }

    static func role(_ element: AXUIElement) -> String {
        string(element, kAXRoleAttribute as String) ?? ""
    }

    static func title(_ element: AXUIElement) -> String {
        string(element, kAXTitleAttribute as String) ?? ""
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard
            let posValue = copyAttribute(element, kAXPositionAttribute as String),
            let sizeValue = copyAttribute(element, kAXSizeAttribute as String)
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    // MARK: - Dock element

    static func dockElement() -> AXUIElement? {
        guard let dock = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock")
            .first
        else {
            return nil
        }
        return AXUIElementCreateApplication(dock.processIdentifier)
    }

    /// Returns the "Mission Control" AXGroup if MC is currently open, else nil.
    static func missionControlGroup(in dock: AXUIElement) -> AXUIElement? {
        for child in children(dock) where role(child) == kAXGroupRole as String {
            if title(child) == "Mission Control" {
                return child
            }
        }
        return nil
    }

    /// Cheap check: is Mission Control currently open? Only inspects the Dock's
    /// top-level children (no deep tree walk), so it's fast enough to call often
    /// for instant teardown detection.
    static func isMissionControlOpen() -> Bool {
        guard let dock = dockElement() else { return false }
        return missionControlGroup(in: dock) != nil
    }

    /// Reads all thumbnail buttons under the Mission Control group.
    /// Returns nil when Mission Control is not open.
    static func currentThumbnails() -> [Thumbnail]? {
        guard let dock = dockElement() else { return nil }
        guard let mcGroup = missionControlGroup(in: dock) else { return nil }

        var results: [Thumbnail] = []
        collectThumbnails(from: mcGroup, into: &results, depth: 0)
        return results
    }

    /// Recursively walks the MC subtree, collecting window thumbnails.
    ///
    /// Window thumbnails are AXButtons living inside a space's content group.
    /// We deliberately KEEP empty-title buttons: some apps (e.g. TablePlus)
    /// expose windows with an empty AXTitle, and those still deserve a chip —
    /// their identity is recovered later via geometry matching. We still exclude:
    ///  * the Spaces Bar group ("Desktop 1/2/…" plus the add-desktop chrome),
    ///  * anything with a negative Y origin (off-screen chrome sits above 0).
    private static func collectThumbnails(from element: AXUIElement, into results: inout [Thumbnail], depth: Int) {
        if depth > 10 { return }

        for child in children(element) {
            let childRole = role(child)
            let childTitle = title(child)

            // Skip the Spaces Bar group entirely (Desktop 1/2/… + add-desktop button).
            if childRole == kAXGroupRole as String, childTitle == "Spaces Bar" {
                continue
            }

            if childRole == kAXButtonRole as String,
               let f = frame(child),
               f.minY >= 0,
               f.width > 60, f.height > 40 {
                results.append(Thumbnail(title: childTitle, axFrame: f))
            }

            collectThumbnails(from: child, into: &results, depth: depth + 1)
        }
    }
}

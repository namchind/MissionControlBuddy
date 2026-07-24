import AppKit
import CoreGraphics

final class WindowCatalogService {
    private let hiddenOwners: Set<String> = [
        "Window Server",
        "Dock",
        "SystemUIServer",
        "NotificationCenter",
        "Control Center"
    ]

    func fetchWindows() -> [WindowSnapshot] {
        guard let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let windows = rawList.compactMap { parseWindow(from: $0) }
        return windows.sorted {
            if $0.appName == $1.appName {
                return $0.windowTitle.localizedCaseInsensitiveCompare($1.windowTitle) == .orderedAscending
            }
            return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    private func parseWindow(from dictionary: [String: Any]) -> WindowSnapshot? {
        guard
            let idNumber = dictionary[kCGWindowNumber as String] as? NSNumber,
            let pidNumber = dictionary[kCGWindowOwnerPID as String] as? NSNumber,
            let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
            let boundsInfo = dictionary[kCGWindowBounds as String] as? [String: Any],
            let x = boundsInfo["X"] as? NSNumber,
            let y = boundsInfo["Y"] as? NSNumber,
            let width = boundsInfo["Width"] as? NSNumber,
            let height = boundsInfo["Height"] as? NSNumber,
            let layer = dictionary[kCGWindowLayer as String] as? NSNumber
        else {
            return nil
        }

        let bounds = CGRect(x: x.doubleValue, y: y.doubleValue, width: width.doubleValue, height: height.doubleValue)

        guard layer.intValue == 0 else { return nil }
        guard !hiddenOwners.contains(ownerName) else { return nil }
        guard bounds.width > 80, bounds.height > 40 else { return nil }

        let windowTitle = (dictionary[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = (windowTitle?.isEmpty == false) ? windowTitle! : "Untitled Window"

        let pid = pid_t(pidNumber.int32Value)
        let app = NSRunningApplication(processIdentifier: pid)
        let icon = app?.icon
        let friendlyAppName = app?.localizedName ?? ownerName
        let screenName = findScreenName(for: bounds)

        return WindowSnapshot(
            windowID: CGWindowID(idNumber.uint32Value),
            ownerPID: pid,
            appName: friendlyAppName,
            windowTitle: cleanTitle,
            bounds: bounds,
            screenName: screenName,
            icon: icon
        )
    }

    private func findScreenName(for windowBounds: CGRect) -> String {
        let center = CGPoint(x: windowBounds.midX, y: windowBounds.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen.localizedName
        }

        return "Unknown Display"
    }
}

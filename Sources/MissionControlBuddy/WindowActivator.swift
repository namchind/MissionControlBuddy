import AppKit
import ApplicationServices

final class WindowActivator {
    func activateWindow(_ window: WindowSnapshot) {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else { return }

        app.activate(options: [.activateIgnoringOtherApps])

        guard AXIsProcessTrusted() else { return }

        let appElement = AXUIElementCreateApplication(window.ownerPID)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        guard result == .success,
              let axWindows = value as? [AXUIElement]
        else {
            return
        }

        for axWindow in axWindows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            let title = (titleValue as? String) ?? ""

            if title == window.windowTitle || (window.windowTitle == "Untitled Window" && title.isEmpty) {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                break
            }
        }
    }
}

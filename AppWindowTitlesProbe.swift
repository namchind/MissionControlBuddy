#!/usr/bin/env swift
//
// AppWindowTitlesProbe.swift
//
// Probe #4: what window titles does each running app expose via the
// Accessibility API? And what does CGWindowList report (owner + title)?
//
// This tells us WHY Chrome doesn't resolve: Chromium apps often don't expose
// their windows via AX unless AXManualAccessibility is enabled. If Chrome's AX
// window list is empty here, that's the smoking gun and we switch strategy.
//
// HOW TO RUN
//   1. Terminal needs Accessibility permission.
//   2. Have Chrome + VS Code open with real windows.
//   3. swift AppWindowTitlesProbe.swift
//

import AppKit
import ApplicationServices

func copyAttr(_ element: AXUIElement, _ attr: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
    return value
}

func axWindows(_ pid: pid_t) -> [AXUIElement] {
    let app = AXUIElementCreateApplication(pid)
    return (copyAttr(app, kAXWindowsAttribute as String) as? [AXUIElement]) ?? []
}

func axTitle(_ element: AXUIElement) -> String {
    (copyAttr(element, kAXTitleAttribute as String) as? String) ?? ""
}

guard AXIsProcessTrusted() else {
    print("❌ Accessibility not granted. Enable it and re-run.")
    exit(1)
}

print("═══════════ Per-app AX window titles ═══════════\n")

let apps = NSWorkspace.shared.runningApplications
    .filter { $0.activationPolicy == .regular }
    .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

for app in apps {
    let name = app.localizedName ?? "?"
    let windows = axWindows(app.processIdentifier)
    print("▸ \(name)  (pid \(app.processIdentifier))  — \(windows.count) AX window(s)")
    for window in windows {
        print("      title = \"\(axTitle(window))\"")
    }
}

print("\n═══════════ CGWindowList (owner + title) ═══════════")
print("(title is blank unless Screen Recording is granted)\n")

if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    for dict in list {
        guard
            let owner = dict[kCGWindowOwnerName as String] as? String,
            let layer = dict[kCGWindowLayer as String] as? NSNumber,
            layer.intValue == 0
        else { continue }
        let title = (dict[kCGWindowName as String] as? String) ?? ""
        let pid = (dict[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1
        print("▸ \(owner)  (pid \(pid))   title=\"\(title)\"")
    }
}

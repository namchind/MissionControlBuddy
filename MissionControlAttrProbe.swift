#!/usr/bin/env swift
//
// MissionControlAttrProbe.swift
//
// Probe #3: dump EVERY accessibility attribute (+ value) of each Mission
// Control thumbnail button. We need this to figure out how to reliably
// identify the owning app — window titles alone mislabel browsers (Chrome
// tabs can be titled "Visual Studio Code FAQ", etc.).
//
// HOW TO RUN
//   1. Ensure your terminal has Accessibility permission.
//   2. swift MissionControlAttrProbe.swift
//   3. Press Control+Up to open Mission Control (leave it open).
//   4. Read the dump. Ctrl+C to stop.
//
// Look especially for a Chrome thumbnail and a VS Code thumbnail and compare
// their attributes (AXDescription, AXHelp, AXIdentifier, AXURL, AXSubrole,
// AXValue, AXRoleDescription, etc.).
//

import AppKit
import ApplicationServices

func copyAttr(_ element: AXUIElement, _ attr: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
    return value
}

func attrNames(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyAttributeNames(element, &names) == .success,
          let list = names as? [String] else { return [] }
    return list
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    (copyAttr(element, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
}

func string(_ element: AXUIElement, _ attr: String) -> String? {
    copyAttr(element, attr) as? String
}

func role(_ element: AXUIElement) -> String { string(element, kAXRoleAttribute as String) ?? "" }
func title(_ element: AXUIElement) -> String { string(element, kAXTitleAttribute as String) ?? "" }

func describeValue(_ element: AXUIElement, _ attr: String) -> String {
    guard let value = copyAttr(element, attr) else { return "nil" }
    if let s = value as? String { return "\"\(s)\"" }
    if let n = value as? NSNumber { return n.stringValue }
    if let arr = value as? [AXUIElement] { return "[\(arr.count) AXUIElements]" }
    // AXValue (points/sizes) and everything else:
    let typeID = CFGetTypeID(value)
    if typeID == AXUIElementGetTypeID() { return "<AXUIElement>" }
    return String(describing: value)
}

func dockElement() -> AXUIElement? {
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
    return AXUIElementCreateApplication(dock.processIdentifier)
}

func missionControlGroup(_ dock: AXUIElement) -> AXUIElement? {
    for child in children(dock) where role(child) == kAXGroupRole as String {
        if title(child) == "Mission Control" { return child }
    }
    return nil
}

var thumbnails: [AXUIElement] = []

func collect(_ element: AXUIElement, depth: Int) {
    if depth > 10 { return }
    for child in children(element) {
        let r = role(child)
        let t = title(child)
        if r == kAXGroupRole as String, t == "Spaces Bar" { continue }
        if r == kAXButtonRole as String, !t.isEmpty {
            thumbnails.append(child)
        }
        collect(child, depth: depth + 1)
    }
}

guard AXIsProcessTrusted() else {
    print("❌ Accessibility not granted to this process. Enable it and re-run.")
    exit(1)
}

print("Probe #3 running. Open Mission Control (Control+Up). Ctrl+C to stop.\n")

var dumped = false

while true {
    if let dock = dockElement(), let mc = missionControlGroup(dock) {
        if !dumped {
            thumbnails.removeAll()
            collect(mc, depth: 0)
            print("════════ Found \(thumbnails.count) thumbnail buttons ════════\n")
            for (i, thumb) in thumbnails.enumerated() {
                print("── Thumbnail #\(i): title=\"\(title(thumb))\" ──")
                for name in attrNames(thumb).sorted() {
                    print("     \(name) = \(describeValue(thumb, name))")
                }
                print("")
            }
            print("════════ End dump. Ctrl+C to stop. ════════")
            dumped = true
        }
    } else {
        dumped = false
    }
    usleep(300_000)
}

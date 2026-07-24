#!/usr/bin/env swift
//
// MissionControlAXProbe.swift
//
// Probe #2: can we read Mission Control thumbnails via the ACCESSIBILITY tree?
//
// The public window list (Probe #1) proved the thumbnails are NOT separate
// windows — they're painted inside one big Dock window. Our last clean hope is
// that the Dock process exposes each thumbnail as an AXUIElement (position,
// size, title). This probe walks the Dock's AX tree while MC is open and prints
// anything that looks like a thumbnail.
//
// HOW TO RUN
//   1. Grant Accessibility to your terminal:
//        System Settings → Privacy & Security → Accessibility → enable Terminal/iTerm
//   2. swift MissionControlAXProbe.swift
//   3. Press Control+Up to open Mission Control (it stays open).
//   4. Watch the dump. Press Escape to close MC, Ctrl+C to stop the probe.
//

import AppKit
import ApplicationServices

// ---- AX helpers ------------------------------------------------------------

func axString(_ element: AXUIElement, _ attr: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return nil }
    return value as? String
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
          let arr = value as? [AXUIElement] else { return [] }
    return arr
}

func axFrame(_ element: AXUIElement) -> CGRect? {
    var posValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
          AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success
    else { return nil }

    var point = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return CGRect(origin: point, size: size)
}

func role(_ element: AXUIElement) -> String { axString(element, kAXRoleAttribute as String) ?? "?" }
func subrole(_ element: AXUIElement) -> String { axString(element, kAXSubroleAttribute as String) ?? "" }
func title(_ element: AXUIElement) -> String { axString(element, kAXTitleAttribute as String) ?? "" }

// ---- tree walk -------------------------------------------------------------

var nodeCount = 0
let maxNodes = 600
let maxDepth = 12

func walk(_ element: AXUIElement, depth: Int) {
    if nodeCount >= maxNodes { return }
    nodeCount += 1

    let r = role(element)
    let sr = subrole(element)
    let t = title(element)
    let frame = axFrame(element)

    // Print anything with a title, or a frame that looks thumbnail-ish,
    // or structural containers so we can see the shape of the tree.
    let frameStr: String
    if let f = frame {
        frameStr = "(\(Int(f.origin.x)),\(Int(f.origin.y)) \(Int(f.width))x\(Int(f.height)))"
    } else {
        frameStr = "no-frame"
    }

    let indent = String(repeating: "  ", count: depth)
    let srStr = sr.isEmpty ? "" : "/\(sr)"
    let tStr = t.isEmpty ? "" : "  title=\"\(t)\""
    print("\(indent)\(r)\(srStr) \(frameStr)\(tStr)")

    for child in axChildren(element) {
        walk(child, depth: depth + 1)
    }
}

// ---- main loop -------------------------------------------------------------

guard AXIsProcessTrusted() else {
    print("❌ Accessibility permission NOT granted to this process.")
    print("   Grant it: System Settings → Privacy & Security → Accessibility → enable your terminal, then re-run.")
    exit(1)
}

func dockApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
}

guard let dock = dockApp() else {
    print("❌ Could not find the Dock process. Weird. Bailing.")
    exit(1)
}

let dockElement = AXUIElementCreateApplication(dock.processIdentifier)

print("✅ Accessibility granted. Watching Dock AX tree (pid \(dock.processIdentifier)).")
print("   Press Control+Up to open Mission Control now. Ctrl+C to stop.\n")

var lastChildCount = -1

func timestamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}

while true {
    let topChildren = axChildren(dockElement)
    let count = topChildren.count

    if count != lastChildCount {
        print("══════ Dock AX top-level children: \(lastChildCount) → \(count) @ \(timestamp()) ══════")
        nodeCount = 0
        walk(dockElement, depth: 0)
        print("   (printed \(nodeCount) nodes, cap \(maxNodes))\n")
        lastChildCount = count
    }

    usleep(400_000) // 400ms
}

#!/usr/bin/env swift
//
// MissionControlProbe.swift
//
// A diagnostic probe that tells us whether native macOS Mission Control
// is enhance-able via overlays on THIS machine / macOS version.
//
// It polls the on-screen window list ~10x/sec and reports:
//   * when the window population suddenly changes (Mission Control likely opened)
//   * every window owned by "Dock" / "WindowServer" with its layer + bounds
//   * whether those windows expose usable rectangles we could overlay onto
//
// Run it, then trigger Mission Control (Control+Up or a trackpad swipe-up).
// Watch the output. Press Ctrl+C to stop.
//
//   swift MissionControlProbe.swift
//

import AppKit
import CoreGraphics

// Owners that are interesting when Mission Control is active.
// Mission Control thumbnails are drawn by the Dock process.
let interestingOwners: Set<String> = ["Dock", "WindowServer", "Mission Control"]

struct RawWindow {
    let windowID: CGWindowID
    let owner: String
    let name: String
    let layer: Int
    let bounds: CGRect
    let alpha: Double
}

func snapshot() -> [RawWindow] {
    let options: CGWindowListOption = [.optionOnScreenOnly]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return []
    }

    return list.compactMap { dict in
        guard
            let id = dict[kCGWindowNumber as String] as? NSNumber,
            let owner = dict[kCGWindowOwnerName as String] as? String,
            let layer = dict[kCGWindowLayer as String] as? NSNumber,
            let boundsInfo = dict[kCGWindowBounds as String] as? [String: Any],
            let x = boundsInfo["X"] as? NSNumber,
            let y = boundsInfo["Y"] as? NSNumber,
            let w = boundsInfo["Width"] as? NSNumber,
            let h = boundsInfo["Height"] as? NSNumber
        else {
            return nil
        }

        let name = (dict[kCGWindowName as String] as? String) ?? ""
        let alpha = (dict[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0

        return RawWindow(
            windowID: CGWindowID(id.uint32Value),
            owner: owner,
            name: name,
            layer: layer.intValue,
            bounds: CGRect(x: x.doubleValue, y: y.doubleValue, width: w.doubleValue, height: h.doubleValue),
            alpha: alpha
        )
    }
}

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

func dumpInteresting(_ windows: [RawWindow], header: String) {
    let dockWindows = windows.filter { interestingOwners.contains($0.owner) }
    print("── \(header) @ \(timestamp()) ─────────────────────────")
    print("   total on-screen windows: \(windows.count)")
    print("   Dock/WindowServer windows: \(dockWindows.count)")

    // Group by owner+layer so we can see the "thumbnail cluster" if it appears.
    let byLayer = Dictionary(grouping: dockWindows, by: { "\($0.owner) L\($0.layer)" })
    for key in byLayer.keys.sorted() {
        let group = byLayer[key]!
        print("   [\(key)] count=\(group.count)")
        for win in group.prefix(40) {
            let b = win.bounds
            let rect = "(\(Int(b.origin.x)),\(Int(b.origin.y)) \(Int(b.width))x\(Int(b.height)))"
            let title = win.name.isEmpty ? "" : " \"\(win.name)\""
            print("      • id=\(win.windowID) a=\(String(format: "%.2f", win.alpha)) \(rect)\(title)")
        }
    }
    print("")
}

// ---- main loop -------------------------------------------------------------

print("MissionControlProbe running. Trigger Mission Control (Control+Up or swipe up).")
print("Watching for population changes… Ctrl+C to stop.\n")

var lastDockCount = -1
var lastTotal = -1
var tick = 0

// Baseline snapshot immediately.
let baseline = snapshot()
dumpInteresting(baseline, header: "BASELINE (Mission Control NOT active)")
lastDockCount = baseline.filter { interestingOwners.contains($0.owner) }.count
lastTotal = baseline.count

while true {
    tick += 1
    let windows = snapshot()
    let dockCount = windows.filter { interestingOwners.contains($0.owner) }.count

    // A meaningful jump in Dock-owned windows usually means MC opened/closed.
    if dockCount != lastDockCount || abs(windows.count - lastTotal) > 3 {
        let direction = dockCount > lastDockCount ? "▲ ACTIVATED?" : "▼ changed"
        dumpInteresting(windows, header: "CHANGE \(direction) (dock \(lastDockCount)→\(dockCount))")
        lastDockCount = dockCount
        lastTotal = windows.count
    }

    // Every ~5s print a heartbeat so you know it's alive.
    if tick % 50 == 0 {
        print("   …alive @ \(timestamp()) (dock windows: \(dockCount), total: \(windows.count))")
    }

    usleep(100_000) // 100ms → 10Hz
}

#!/usr/bin/env swift
//
// make_icon.swift
//
// Generates Resources/AppIcon.icns for MissionControlBuddy.
// Motif: a Mission Control grid of window cards, each with a little labelled
// chip (icon dot + title lines) — exactly what the app does.
//
// Run:  swift make_icon.swift
//

import AppKit

// MARK: - Drawing

func drawIcon(pixelSize: CGFloat, into context: CGContext) {
    let s = pixelSize
    let ns = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = ns

    // Rounded background with a diagonal gradient (macOS-ish blue → indigo).
    let bgRect = NSRect(x: 0, y: 0, width: s, height: s)
    let bgRadius = s * 0.2237 // matches macOS icon squircle-ish rounding
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: bgRadius, yRadius: bgRadius)
    bgPath.addClip()

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.30, green: 0.56, blue: 0.98, alpha: 1.0),
        NSColor(srgbRed: 0.38, green: 0.32, blue: 0.92, alpha: 1.0)
    ])
    gradient?.draw(in: bgRect, angle: -60)

    // Content inset (the "screen" region).
    let inset = s * 0.17
    let gap = s * 0.055
    let area = s - inset * 2
    let cardW = (area - gap) / 2
    let cardH = (area - gap) / 2

    let accents = [
        NSColor(srgbRed: 0.98, green: 0.42, blue: 0.42, alpha: 1.0),
        NSColor(srgbRed: 0.36, green: 0.80, blue: 0.52, alpha: 1.0),
        NSColor(srgbRed: 0.98, green: 0.74, blue: 0.30, alpha: 1.0),
        NSColor(srgbRed: 0.55, green: 0.45, blue: 0.95, alpha: 1.0)
    ]

    // Grid positions (bottom-left origin): draw top row first visually.
    let positions = [
        NSPoint(x: inset, y: inset + cardH + gap),        // top-left
        NSPoint(x: inset + cardW + gap, y: inset + cardH + gap), // top-right
        NSPoint(x: inset, y: inset),                       // bottom-left
        NSPoint(x: inset + cardW + gap, y: inset)          // bottom-right
    ]

    for (i, pos) in positions.enumerated() {
        drawWindowCard(
            rect: NSRect(x: pos.x, y: pos.y, width: cardW, height: cardH),
            accent: accents[i],
            unit: s
        )
    }

    ns.flushGraphics()
    NSGraphicsContext.current = nil
}

func drawWindowCard(rect: NSRect, accent: NSColor, unit s: CGFloat) {
    // Card shadow.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
    shadow.set()

    let cardRadius = s * 0.032
    let cardPath = NSBezierPath(roundedRect: rect, xRadius: cardRadius, yRadius: cardRadius)
    NSColor.white.setFill()
    cardPath.fill()

    // Reset shadow for inner content.
    let noShadow = NSShadow()
    noShadow.shadowColor = .clear
    noShadow.set()

    // Little "label chip" pinned to the card's bottom-left — the app's signature.
    let chipH = rect.height * 0.30
    let chipW = rect.width * 0.72
    let chipPad = rect.width * 0.08
    let chipRect = NSRect(
        x: rect.minX + chipPad,
        y: rect.minY + chipPad,
        width: chipW,
        height: chipH
    )
    let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: chipH * 0.28, yRadius: chipH * 0.28)
    NSColor.black.withAlphaComponent(0.82).setFill()
    chipPath.fill()

    // App icon dot inside the chip.
    let dotD = chipH * 0.56
    let dotRect = NSRect(
        x: chipRect.minX + chipH * 0.22,
        y: chipRect.midY - dotD / 2,
        width: dotD,
        height: dotD
    )
    accent.setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    // Two title lines next to the dot.
    let lineX = dotRect.maxX + chipH * 0.18
    let lineW = chipRect.maxX - lineX - chipH * 0.20
    let lineH = chipH * 0.14
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: NSRect(x: lineX, y: chipRect.midY + lineH * 0.2, width: lineW, height: lineH), xRadius: lineH / 2, yRadius: lineH / 2).fill()
    NSColor.white.withAlphaComponent(0.6).setFill()
    NSBezierPath(roundedRect: NSRect(x: lineX, y: chipRect.midY - lineH * 1.4, width: lineW * 0.7, height: lineH), xRadius: lineH / 2, yRadius: lineH / 2).fill()
}

// MARK: - Export

func renderPNG(pixelSize: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    drawIcon(pixelSize: CGFloat(pixelSize), into: ctx.cgContext)

    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconsetDir = "AppIcon.iconset"
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// (filename, pixel size)
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in variants {
    let data = renderPNG(pixelSize: size)
    try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
    print("• \(name) (\(size)px)")
}

// Build the .icns via iconutil.
try? fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", "Resources/AppIcon.icns"]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ Wrote Resources/AppIcon.icns")
    try? fm.removeItem(atPath: iconsetDir)
} else {
    print("❌ iconutil failed (status \(task.terminationStatus)); iconset kept at \(iconsetDir)")
}

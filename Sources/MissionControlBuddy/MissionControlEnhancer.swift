import AppKit
import ApplicationServices

/// Watches for native Mission Control activation and overlays app icon + name
/// (+ window title) chips on each thumbnail.
@MainActor
final class MissionControlEnhancer {

    private var pollTimer: Timer?
    private var overlays: [ThumbnailOverlayWindow] = []
    private var iconResolver = IconResolver()
    private var isShowingOverlays = false

    private(set) var isEnabled = true

    // MARK: - Lifecycle

    func start() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(
            timeInterval: 0.15,
            target: self,
            selector: #selector(poll),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        tearDownOverlays()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            tearDownOverlays()
        }
    }

    // MARK: - Polling

    @objc private func poll() {
        guard isEnabled else { return }

        guard let thumbnails = DockAXReader.currentThumbnails(), !thumbnails.isEmpty else {
            // Mission Control is closed (or empty) → clear overlays.
            if isShowingOverlays { tearDownOverlays() }
            return
        }

        if !isShowingOverlays {
            // Fresh activation: rebuild the icon lookup once.
            iconResolver.refresh()
            isShowingOverlays = true
        }

        render(thumbnails)
    }

    // MARK: - Rendering

    private func render(_ thumbnails: [Thumbnail]) {
        // Recreate overlays each frame — cheap for a handful of windows, and
        // keeps rects in sync as MC animates thumbnails into place.
        tearDownOverlays(keepFlag: true)

        for thumbnail in thumbnails {
            guard let cocoaFrame = cocoaFrame(from: thumbnail.axFrame) else { continue }

            let resolved = iconResolver.resolve(title: thumbnail.title)
            let overlay = ThumbnailOverlayWindow(cocoaFrame: cocoaFrame)
            overlay.update(icon: resolved.icon, appName: resolved.appName, windowTitle: thumbnail.title)
            overlay.orderFrontRegardless()
            overlays.append(overlay)
        }
    }

    private func tearDownOverlays(keepFlag: Bool = false) {
        for overlay in overlays {
            overlay.orderOut(nil)
        }
        overlays.removeAll(keepingCapacity: true)
        if !keepFlag {
            isShowingOverlays = false
        }
    }

    // MARK: - Coordinate conversion

    /// Converts an AX/global rect (top-left origin, y-down) to a Cocoa screen
    /// rect (bottom-left origin, y-up).
    private func cocoaFrame(from axFrame: CGRect) -> NSRect? {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        guard let primaryScreen = primary else { return nil }

        let primaryMaxY = primaryScreen.frame.maxY
        let cocoaY = primaryMaxY - axFrame.origin.y - axFrame.height
        return NSRect(x: axFrame.origin.x, y: cocoaY, width: axFrame.width, height: axFrame.height)
    }
}

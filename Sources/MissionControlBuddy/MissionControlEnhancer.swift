import AppKit
import ApplicationServices

/// Watches for native Mission Control activation and overlays app icon + name
/// (+ window title) chips on each thumbnail.
///
/// Performance design:
///  * A pool of overlay windows is REUSED across frames (no create/destroy
///    churn — that was the source of the left-edge flicker and teardown lag).
///  * A cheap "is MC open?" check runs every tick for instant teardown.
///  * Overlays only move/redraw when their frame or content actually changes.
@MainActor
final class MissionControlEnhancer {

    private var pollTimer: Timer?
    private var overlayPool: [ThumbnailOverlayWindow] = []
    private var activeCount = 0
    private var iconResolver = IconResolver()
    private var isShowingOverlays = false

    private var suppressedUntilMCClosed = false
    private var mouseMonitor: Any?

    private(set) var isEnabled = true

    // MARK: - Lifecycle

    func start() {
        guard pollTimer == nil else { return }
        // 60ms (~16Hz): responsive without hammering the Dock AX bridge.
        pollTimer = Timer.scheduledTimer(
            timeInterval: 0.06,
            target: self,
            selector: #selector(poll),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        hideAllOverlays()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            hideAllOverlays()
        }
    }

    // MARK: - Polling

    @objc private func poll() {
        guard isEnabled else { return }

        // Fast path: if MC isn't open, hide everything immediately. This is the
        // cheap top-level check, so teardown feels instant.
        guard DockAXReader.isMissionControlOpen() else {
            if suppressedUntilMCClosed { suppressedUntilMCClosed = false }
            if isShowingOverlays { hideAllOverlays() }
            return
        }

        // If the user just selected a window in MC, we suppress re-drawing until
        // Mission Control actually closes (prevents the "one last draw" glitch).
        if suppressedUntilMCClosed {
            return
        }

        guard let thumbnails = DockAXReader.currentThumbnails(), !thumbnails.isEmpty else {
            if isShowingOverlays { hideAllOverlays() }
            return
        }

        if !isShowingOverlays {
            iconResolver.refresh()   // rebuild icon lookup once per activation
            isShowingOverlays = true
            installSelectionMonitor()
        }

        render(thumbnails)
    }

    // MARK: - Rendering (reuses pooled windows)

    private func render(_ thumbnails: [Thumbnail]) {
        for (index, thumbnail) in thumbnails.enumerated() {
            guard let cocoaFrame = cocoaFrame(from: thumbnail.axFrame) else { continue }

            let overlay = overlay(at: index)
            let resolved = iconResolver.resolve(title: thumbnail.title, appHint: thumbnail.appHint)

            overlay.setFrameIfNeeded(cocoaFrame)
            overlay.updateIfNeeded(icon: resolved.icon, appName: resolved.appName, windowTitle: thumbnail.title)
            if !overlay.isVisible {
                overlay.orderFrontRegardless()
            }
        }

    // Hide any leftover overlays from a previous frame with more thumbnails.
        if thumbnails.count < activeCount {
            for index in thumbnails.count..<activeCount {
                overlayPool[index].orderOut(nil)
            }
        }
        activeCount = thumbnails.count
    }

    /// Returns a pooled overlay window, creating one lazily if needed.
    private func overlay(at index: Int) -> ThumbnailOverlayWindow {
        if index < overlayPool.count {
            return overlayPool[index]
        }
        let overlay = ThumbnailOverlayWindow()
        overlayPool.append(overlay)
        return overlay
    }

    private func hideAllOverlays() {
        for overlay in overlayPool where overlay.isVisible {
            overlay.orderOut(nil)
        }
        activeCount = 0
        isShowingOverlays = false
        removeSelectionMonitor()
    }

    private func installSelectionMonitor() {
        guard mouseMonitor == nil else { return }
        // Any click while Mission Control is open usually means "select a window".
        // Hide immediately so overlays never linger over the chosen app.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isShowingOverlays {
                    self.suppressedUntilMCClosed = true
                    self.hideAllOverlays()
                }
            }
        }
    }

    private func removeSelectionMonitor() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    // MARK: - Coordinate conversion

    /// Converts an AX/global rect (top-left origin, y-down) to a Cocoa screen
    /// rect (bottom-left origin, y-up).
    private func cocoaFrame(from axFrame: CGRect) -> NSRect? {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        guard let primaryScreen = primary else { return nil }

        let cocoaY = primaryScreen.frame.maxY - axFrame.origin.y - axFrame.height
        return NSRect(x: axFrame.origin.x, y: cocoaY, width: axFrame.width, height: axFrame.height)
    }
}

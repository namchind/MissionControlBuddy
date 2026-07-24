import AppKit
import CoreGraphics

struct WindowSnapshot {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let appName: String
    let windowTitle: String
    let bounds: CGRect
    let screenName: String
    let icon: NSImage?

    var subtitle: String {
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        return "\(screenName) • \(width)x\(height)"
    }
}

import Foundation
import ServiceManagement

/// Wraps "launch at login" using SMAppService (macOS 13+).
///
/// Note: this only works when the app runs as a proper bundled .app that is
/// registered with launchd. When running via `swift run` (a bare executable),
/// registration may fail — see README for building the .app.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns true on success. Silently returns false if registration isn't
    /// possible in the current run context (e.g. `swift run`).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("LoginItem: failed to set enabled=\(enabled): \(error)")
            return false
        }
    }
}

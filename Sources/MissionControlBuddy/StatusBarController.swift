import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let windowListController = WindowListViewController()

    private var refreshTimer: Timer?

    override init() {
        super.init()
        setupStatusBarButton()
        setupPopover()
    }


    private func setupStatusBarButton() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "rectangle.3.group.bubble.left", accessibilityDescription: "Mission Control Buddy")
        button.image?.isTemplate = true
        button.toolTip = "Mission Control Buddy"
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 560, height: 480)
        popover.behavior = .transient
        popover.contentViewController = windowListController

        windowListController.onRequestClose = { [weak self] in
            self?.popover.performClose(nil)
            self?.stopRefreshing()
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            stopRefreshing()
        } else {
            windowListController.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            startRefreshing()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh Windows", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit MissionControlBuddy", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshNow() {
        windowListController.refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func startRefreshing() {
        stopRefreshing()
        refreshTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(refreshNow), userInfo: nil, repeats: true)
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

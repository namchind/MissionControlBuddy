import AppKit

/// A simple programmatic preferences window.
@MainActor
final class PreferencesWindowController: NSWindowController {

    private let prefs = PreferencesStore.shared

    // Callbacks supplied by AppDelegate.
    var overlayEnabledProvider: (() -> Bool)?
    var setOverlayEnabled: ((Bool) -> Void)?
    var quitHandler: (() -> Void)?
    var menuIconVisibilityChanged: ((Bool) -> Void)?

    private let overlaysCheckbox = NSButton(checkboxWithTitle: "Enable overlays", target: nil, action: nil)
    private let scaleSlider = NSSlider()
    private let scaleValueLabel = NSTextField(labelWithString: "")
    private let colorWell = NSColorWell()
    private let opacitySlider = NSSlider()
    private let opacityValueLabel = NSTextField(labelWithString: "")
    private let longTextControl = NSSegmentedControl()
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let menuIconCheckbox = NSButton(checkboxWithTitle: "Show menu bar icon", target: nil, action: nil)
    private let loginNoteLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mission Control Buddy — Preferences"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
        loadValues()
    }

    func showAndFocus() {
        loadValues()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // Header: app icon + name + version (fittingly, an icon app shows its icon).
        let iconView = NSImageView()
        iconView.image = AppInfo.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(iconView)

        let titleLabel = NSTextField(labelWithString: AppInfo.displayName)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        let versionLabel = NSTextField(labelWithString: "Version \(AppInfo.version)")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        let titleStack = NSStackView(views: [titleLabel, versionLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleStack)

        overlaysCheckbox.target = self
        overlaysCheckbox.action = #selector(overlaysToggled)

        scaleSlider.minValue = 0.6
        scaleSlider.maxValue = 1.8
        scaleSlider.target = self
        scaleSlider.action = #selector(scaleChanged)

        opacitySlider.minValue = 0.0
        opacitySlider.maxValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)

        colorWell.target = self
        colorWell.action = #selector(colorChanged)

        longTextControl.segmentCount = LongTextBehavior.allCases.count
        for (i, behavior) in LongTextBehavior.allCases.enumerated() {
            longTextControl.setLabel(behavior.displayName, forSegment: i)
            longTextControl.setWidth(120, forSegment: i)
        }
        longTextControl.target = self
        longTextControl.action = #selector(longTextChanged)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginToggled)

        menuIconCheckbox.target = self
        menuIconCheckbox.action = #selector(menuIconToggled)

        loginNoteLabel.font = .systemFont(ofSize: 10)
        loginNoteLabel.textColor = .secondaryLabelColor
        loginNoteLabel.stringValue = "Launch at login works only when running the built .app (not swift run)."

        let grid = NSGridView(views: [
            [label("Runtime:"), overlaysCheckbox],
            [label("Chip size:"), sliderRow(scaleSlider, scaleValueLabel)],
            [label("Background:"), colorWell],
            [label("Opacity:"), sliderRow(opacitySlider, opacityValueLabel)],
            [label("Long text:"), longTextControl],
            [label("Startup:"), loginCheckbox],
            [label("UI:"), menuIconCheckbox],
            [NSGridCell.emptyContentView, loginNoteLabel]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 12
        grid.rowSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        content.addSubview(grid)

        let resetButton = NSButton(title: "Restore Defaults", target: self, action: #selector(resetToDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(resetButton)

        let quitButton = NSButton(title: "Quit MissionControlBuddy", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(quitButton)

        let aboutButton = NSButton(title: "About", target: self, action: #selector(showAbout))
        aboutButton.bezelStyle = .rounded
        aboutButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(aboutButton)

        // Closes the window but leaves the app running in the menu bar.
        let doneButton = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r" // Return activates it
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(doneButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            iconView.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

            titleStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleStack.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            grid.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),

            resetButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            resetButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),

            aboutButton.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor, constant: 12),
            aboutButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),

            quitButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            quitButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),

            doneButton.trailingAnchor.constraint(equalTo: quitButton.leadingAnchor, constant: -12),
            doneButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func sliderRow(_ slider: NSSlider, _ valueLabel: NSTextField) -> NSView {
        valueLabel.alignment = .right
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [slider, valueLabel])
        stack.orientation = .horizontal
        stack.spacing = 8
        slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return stack
    }

    // MARK: - Load / actions

    private func loadValues() {
        overlaysCheckbox.state = (overlayEnabledProvider?() ?? true) ? .on : .off
        scaleSlider.doubleValue = prefs.chipScale
        scaleValueLabel.stringValue = String(format: "%.0f%%", prefs.chipScale * 100)
        opacitySlider.doubleValue = prefs.backgroundOpacity
        opacityValueLabel.stringValue = String(format: "%.0f%%", prefs.backgroundOpacity * 100)
        colorWell.color = NSColor(hex: prefs.backgroundHex) ?? .black
        if let index = LongTextBehavior.allCases.firstIndex(of: prefs.longTextBehavior) {
            longTextControl.selectedSegment = index
        }
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        menuIconCheckbox.state = prefs.showMenuBarIcon ? .on : .off
    }

    @objc private func overlaysToggled() {
        setOverlayEnabled?(overlaysCheckbox.state == .on)
    }

    @objc private func scaleChanged() {
        prefs.chipScale = scaleSlider.doubleValue
        scaleValueLabel.stringValue = String(format: "%.0f%%", prefs.chipScale * 100)
    }

    @objc private func opacityChanged() {
        prefs.backgroundOpacity = opacitySlider.doubleValue
        opacityValueLabel.stringValue = String(format: "%.0f%%", prefs.backgroundOpacity * 100)
    }

    @objc private func colorChanged() {
        prefs.backgroundHex = colorWell.color.hexString
    }

    @objc private func longTextChanged() {
        let index = longTextControl.selectedSegment
        guard index >= 0, index < LongTextBehavior.allCases.count else { return }
        prefs.longTextBehavior = LongTextBehavior.allCases[index]
    }

    @objc private func loginToggled() {
        let wantEnabled = loginCheckbox.state == .on
        let success = LoginItem.setEnabled(wantEnabled)
        if !success {
            loginCheckbox.state = LoginItem.isEnabled ? .on : .off
            loginNoteLabel.stringValue = "Couldn't change login item — run the built .app (see README)."
            loginNoteLabel.textColor = .systemRed
        }
    }

    @objc private func menuIconToggled() {
        let visible = menuIconCheckbox.state == .on
        prefs.showMenuBarIcon = visible
        menuIconVisibilityChanged?(visible)
    }

    @objc private func resetToDefaults() {
        prefs.resetToDefaults()
        loadValues()
        setOverlayEnabled?(true)
        menuIconVisibilityChanged?(prefs.showMenuBarIcon)
    }

    @objc private func quitApp() {
        quitHandler?()
    }

    @objc private func showAbout() {
        AppInfo.presentAbout()
    }

    /// Closes the Preferences window; the app keeps running in the menu bar.
    @objc private func closeWindow() {
        window?.close()
    }
}

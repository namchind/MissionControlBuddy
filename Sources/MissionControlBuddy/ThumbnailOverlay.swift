import AppKit

/// A borderless, click-through overlay that sits on top of a single Mission
/// Control thumbnail and shows the app icon + name (+ window title).
final class ThumbnailOverlayWindow: NSWindow {

    init(cocoaFrame: NSRect) {
        super.init(
            contentRect: cocoaFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Sit above Mission Control. This is the one empirically-uncertain bit;
        // .assistiveTechHigh is intended for accessibility overlays that must
        // float above almost everything.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))

        // Show on every Space and inside Mission Control.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Let clicks pass through to the thumbnail underneath so MC still works.
        ignoresMouseEvents = true

        contentView = ThumbnailLabelView(frame: NSRect(origin: .zero, size: cocoaFrame.size))
    }

    func update(icon: NSImage?, appName: String, windowTitle: String) {
        (contentView as? ThumbnailLabelView)?.configure(icon: icon, appName: appName, windowTitle: windowTitle)
    }
}

/// Draws a compact chip (icon + app name + window title) pinned to the
/// bottom-left of the thumbnail.
final class ThumbnailLabelView: NSView {

    private let iconView = NSImageView()
    private let appNameLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let chip = NSVisualEffectView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        chip.material = .hudWindow
        chip.blendingMode = .withinWindow
        chip.state = .active
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 8
        chip.layer?.masksToBounds = true
        chip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chip)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(iconView)

        appNameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        appNameLabel.textColor = .white
        appNameLabel.lineBreakMode = .byTruncatingTail
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(appNameLabel)

        titleLabel.font = .systemFont(ofSize: 10, weight: .regular)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // Chip pinned bottom-left with a small inset.
            chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            chip.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            chip.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            chip.heightAnchor.constraint(equalToConstant: 40),

            iconView.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            appNameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            appNameLabel.topAnchor.constraint(equalTo: chip.topAnchor, constant: 4),
            appNameLabel.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -8),

            titleLabel.leadingAnchor.constraint(equalTo: appNameLabel.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 1),
            titleLabel.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: chip.bottomAnchor, constant: -4)
        ])
    }

    func configure(icon: NSImage?, appName: String, windowTitle: String) {
        iconView.image = icon
        appNameLabel.stringValue = appName
        // Only show the window title line when it adds information.
        titleLabel.stringValue = (windowTitle == appName) ? "" : windowTitle
    }
}

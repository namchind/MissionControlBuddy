import AppKit

/// A borderless, click-through overlay that sits on top of a single Mission
/// Control thumbnail and shows the app icon + name (+ window title).
final class ThumbnailOverlayWindow: NSWindow {

    private var lastAppName: String?
    private var lastWindowTitle: String?
    private var lastIcon: NSImage?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true

        // Float above Mission Control (confirmed working on the user's macOS).
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        contentView = ThumbnailLabelView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
    }

    /// Move only when the frame actually changed — avoids redundant redraws
    /// that cause flicker.
    func setFrameIfNeeded(_ newFrame: NSRect) {
        if frame != newFrame {
            setFrame(newFrame, display: false, animate: false)
        }
    }

    /// Update content only when it changed.
    func updateIfNeeded(icon: NSImage?, appName: String, windowTitle: String) {
        if appName == lastAppName, windowTitle == lastWindowTitle, icon === lastIcon {
            return
        }
        lastAppName = appName
        lastWindowTitle = windowTitle
        lastIcon = icon
        (contentView as? ThumbnailLabelView)?.configure(icon: icon, appName: appName, windowTitle: windowTitle)
    }
}

/// Draws a compact solid pill (icon + app name + window title) pinned to the
/// bottom-left of the thumbnail. Solid background + text shadow keeps it
/// readable over both light and dark window thumbnails.
final class ThumbnailLabelView: NSView {

    private let iconView = NSImageView()
    private let appNameLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let pill = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        pill.wantsLayer = true
        pill.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        pill.layer?.cornerRadius = 8
        pill.layer?.masksToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(iconView)

        configureLabel(appNameLabel, size: 12, weight: .semibold, color: .white)
        configureLabel(titleLabel, size: 10, weight: .regular, color: NSColor.white.withAlphaComponent(0.8))
        pill.addSubview(appNameLabel)
        pill.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            pill.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            pill.heightAnchor.constraint(equalToConstant: 40),

            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            appNameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            appNameLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 4),
            appNameLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),

            titleLabel.leadingAnchor.constraint(equalTo: appNameLabel.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 1),
            titleLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: pill.bottomAnchor, constant: -4)
        ])
    }

    private func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        // Subtle shadow so text stays legible even if the pill sits over a
        // bright thumbnail edge.
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        label.shadow = shadow
    }

    func configure(icon: NSImage?, appName: String, windowTitle: String) {
        iconView.image = icon
        appNameLabel.stringValue = appName
        titleLabel.stringValue = (windowTitle == appName) ? "" : windowTitle
    }
}

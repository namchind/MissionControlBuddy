# Changelog

All notable changes to Mission Control Buddy are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-28

### Fixed
- **Title-less windows now get an overlay chip.** Apps that expose an empty
  window title (most notably **TablePlus**, but any app with a blank `AXTitle`)
  were dropped by the thumbnail collector and never rendered. Their identity is
  now recovered via uniform-scale aspect-ratio matching, with per-pass claim
  tracking so no two thumbnails resolve to the same window.

### Added
- **Version shown in the About dialog** (e.g. "Mission Control Buddy v1.0.1"),
  read from `CFBundleShortVersionString` at runtime so it always matches the
  bundle — single source of truth in `Info.plist`.

### Docs
- README updated with a direct download link (Installer DMG).

## [1.0.0] - 2026-07-26

### Added
- Initial release: a menu bar utility that enhances the native macOS Mission
  Control (Control+Up / three finger swipe up) by overlaying each window thumbnail with its
  **app icon, app name, and window title**.
- Icon + name + title overlays driven by the Dock's Accessibility tree.
- Ellipsis-aware title matching (handles Mission Control's middle-truncated and
  Chrome-style suffixed titles).
- Preferences window: chip size, background color, opacity, and long-text
  behavior (truncate vs wrap), plus Restore Defaults.
- Launch at Login (via `SMAppService`).
- Hide-menu-bar-icon mode with a Preferences fallback so the app stays
  controllable when the icon is hidden.
- Custom app icon and a proper signed `.app` bundle (`build_app.sh`).

### Performance
- Reused overlay window pool (no create/destroy churn) and a solid pill
  background for readability.
- Stability + renderability gates to suppress overlays during the Mission
  Control open/close animation and partial-swipe transitions.

[1.0.1]: https://github.com/your-org/MissionControlBuddy/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/your-org/MissionControlBuddy/releases/tag/1.0.0

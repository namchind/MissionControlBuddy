# MissionControlBuddy

**Enhances the *native* macOS Mission Control** (Control+Up / swipe up) by
overlaying each window thumbnail with its **app icon, app name, and window
title** — so you can find the window you want at a glance.

This is **not** a Mission Control clone. It watches for the real, Apple-provided
Mission Control and draws labels on top of the actual thumbnails.


Download: <https://github.com/namchind/MissionControlBuddy/releases/download/1.0.0/MissionControlBuddy-v1.0.0-Installer.dmg>

---

## Features

- 🪟 Icon + app name + window title chip on every Mission Control thumbnail
- 🎯 Correctly resolves apps even with truncated / decorated titles (incl. Chrome)
- 🎛️ **Preferences**: chip size, background color, opacity, long-text wrap/cut
- 🚀 **Launch at login** (when installed as an app bundle)
- ⚡ Smart show/hide: appears only when Mission Control is fully open & settled,
  stays hidden during partial swipes and open/close animations
- 🖱️ Click-through overlays — Mission Control keeps working normally

---

## Requirements

- macOS 13 (Ventura) or later
- Swift 6 toolchain (Xcode 16 / Command Line Tools) to build
- **Accessibility permission** (required — that's how we read the thumbnails)

---

## Installation

### Option A — Install as an app (recommended)

This gives you a stable Accessibility entry and enables **Launch at Login**.

```bash
cd MissionControlBuddy
./build_app.sh --install
```

Then:
1. Open **MissionControlBuddy** from `/Applications` (or Spotlight).
2. When prompted, grant **Accessibility**:
   System Settings → Privacy & Security → Accessibility → enable
   **MissionControlBuddy**.
3. Quit and relaunch once so the permission takes effect.
4. Trigger Mission Control (Control+Up or swipe up) — the chips appear. 🎉

To build the app without installing, just run `./build_app.sh`
(output lands in `dist/MissionControlBuddy.app`).

### Option B — Run from source (quick dev loop)

```bash
cd MissionControlBuddy
swift run
```

Grant Accessibility to your **terminal** (System Settings → Privacy & Security →
Accessibility) and relaunch. Note: "Launch at Login" does **not** work in this
mode — use Option A for that.

---

## Usage

- The app lives in the **menu bar** (no Dock icon).
- Click the menu bar icon for:
  - **Enable / Disable Overlays**
  - **Preferences…** (⌘,)
  - **Launch at Login**
  - **Hide Menu Bar Icon**
  - **About**, **Quit**

If you hide the menu bar icon, open MissionControlBuddy again from Spotlight /
Applications to bring back the **Preferences** window (control surface).

### Preferences

| Setting | What it does |
|---------|--------------|
| **Chip size** | Scales icon + text + padding (60%–180%) |
| **Background** | Chip background color (color picker) |
| **Opacity** | Chip background opacity (0–100%) |
| **Long text** | `Cut with …` (truncate) or `Wrap (2 lines)` |
| **Enable overlays** | Runtime on/off switch for Mission Control chips |
| **Launch at login** | Start automatically at login (app bundle only) |
| **Show menu bar icon** | Show/hide status item; when hidden, relaunch app to open Preferences |
| **Restore Defaults** | Reset all settings back to defaults |
| **Quit button** | Stop the app even when menu bar icon is hidden |

Changes apply live to the next Mission Control open.

---

## How it works

Two diagnostic probes established what's possible:

- `MissionControlProbe.swift` — proved thumbnails are **not** separate windows
  in the public window list (they're painted inside one big Dock window).
- `MissionControlAXProbe.swift` / `MissionControlAttrProbe.swift` /
  `AppWindowTitlesProbe.swift` — proved the Dock exposes every thumbnail as an
  `AXButton` (rect + title) under an `AXGroup` titled `"Mission Control"`, and
  showed how titles are truncated/decorated (the key to app resolution).

So the app:

1. Polls the Dock's Accessibility tree (~16 Hz).
2. When the `"Mission Control"` group appears **and the layout is stable and
   grid-like**, reads all thumbnail buttons (rect + title).
3. Resolves each title → owning app → **icon + name** by matching against each
   running app's AX window titles (exact, middle-ellipsis, and prefix matching).
4. Parks a **borderless, click-through** overlay chip on each thumbnail at a
   high window level so it floats above Mission Control.
5. Tears the overlays down the instant the layout changes (dismiss / swipe /
   animation).

---

## ⚠️ Experimental caveats

- Floating above Mission Control uses a high window level
  (`.assistiveTechHighWindow`). See `ThumbnailOverlay.swift` to tweak.
- Relies on the Dock's Accessibility structure, which Apple can change between
  macOS releases.
- Ad-hoc signed / personal-use utility.

---

## Project layout

| File | Role |
|------|------|
| `DockAXReader.swift` | Reads MC thumbnails from the Dock AX tree |
| `IconResolver.swift` | Maps thumbnail title → app icon + name |
| `ThumbnailOverlay.swift` | Borderless click-through chip window + styling |
| `MissionControlEnhancer.swift` | Watcher, stability/render gate, coord flip |
| `Preferences.swift` | UserDefaults-backed settings + color helpers |
| `PreferencesWindowController.swift` | Settings UI window |
| `LoginItem.swift` | Launch-at-login via SMAppService |
| `StatusBarController.swift` | Menu bar UI |
| `AppDelegate.swift` | Startup + Accessibility prompt |
| `build_app.sh` | Builds/install the `.app` bundle |
| `make_icon.swift` | Generates `Resources/AppIcon.icns` |
| `*Probe.swift` | Diagnostics used to reverse-engineer MC |

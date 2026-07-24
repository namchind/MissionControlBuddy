# MissionControlBuddy

**Enhances the *native* macOS Mission Control** (Control+Up / swipe-up) by overlaying
each window thumbnail with its **app icon, app name, and window title** — so you can
find the window you want at a glance.

This is **not** a Mission Control clone. It watches for the real, Apple-provided
Mission Control and draws labels on top of the actual thumbnails.

## How it works (and why it works)

Two diagnostic probes established what's possible on this machine:

- `MissionControlProbe.swift` — proved the thumbnails are **not** separate windows
  in the public window list (they're painted inside one big Dock window).
- `MissionControlAXProbe.swift` — proved the Dock exposes every thumbnail as an
  `AXButton` (with a rectangle + window title) under an `AXGroup` titled
  `"Mission Control"` in its **Accessibility tree**. ✅

So the app:

1. Polls the Dock's Accessibility tree (~7x/sec).
2. When the `"Mission Control"` group appears, reads all thumbnail buttons
   (rect + title).
3. Resolves each title → owning app → **icon + name** (by reading each running
   app's AX window titles — no Screen Recording permission required).
4. Parks a **borderless, click-through** overlay chip on each thumbnail at a high
   window level so it floats above Mission Control.
5. Tears the overlays down when Mission Control closes.

## Requirements

- macOS 13+
- Swift 6 toolchain
- **Accessibility permission** (required — that's how we read the thumbnails)

## Run

```bash
cd MissionControlBuddy
swift run
```

Grant Accessibility when prompted (System Settings → Privacy & Security →
Accessibility → enable this app, or your terminal if running via `swift run`),
then relaunch. Trigger Mission Control (Control+Up or swipe up) and the labels
should appear.

The menu bar icon lets you toggle overlays on/off and quit.

## ⚠️ Experimental caveats

- Floating above Mission Control uses a high window level
  (`.assistiveTechHighWindow`). If overlays don't appear on top on your macOS
  version, this is the knob to tweak (see `ThumbnailOverlay.swift`).
- Relies on the Dock's Accessibility structure, which Apple can change between
  macOS releases.
- Personal-use / unsigned utility.

## Project layout

| File | Role |
|------|------|
| `DockAXReader.swift` | Reads MC thumbnails from the Dock AX tree |
| `IconResolver.swift` | Maps thumbnail title → app icon + name |
| `ThumbnailOverlay.swift` | The borderless click-through label window |
| `MissionControlEnhancer.swift` | Watcher + overlay lifecycle + coordinate flip |
| `StatusBarController.swift` | Menu bar UI (toggle / about / quit) |
| `AppDelegate.swift` | Startup + Accessibility prompt |
| `MissionControlProbe.swift` | Diagnostic #1 (window list) |
| `MissionControlAXProbe.swift` | Diagnostic #2 (AX tree) |

# MissionControlBuddy

MissionControlBuddy is a native macOS menu bar app that makes Mission Control easier to scan.

It adds:
- App icons
- App names
- Window titles
- Display labels
- Search-as-you-type filtering
- One-click activation of the selected window/app

## Why this exists

Mission Control is great, but when you have a lot of windows, finding the right one can get messy.
MissionControlBuddy gives you a compact, searchable, icon-rich view from the menu bar.

## Requirements

- macOS 13+
- Swift 6 toolchain (Xcode command line tools)

## Run

```bash
cd MissionControlBuddy
swift run
```

The app runs as a menu bar utility (`NSApplication` with accessory activation policy).

## Usage

1. Click the menu bar icon.
2. Type in the search bar to filter by app name or window title.
3. Double-click a row to activate that app/window.
4. Right-click the menu bar icon for refresh and quit options.

## Accessibility permission (optional but recommended)

The app can still list windows without Accessibility privileges.
For best window raise/focus behavior, grant Accessibility access:

- System Settings → Privacy & Security → Accessibility
- Add/enable the app or terminal used to run `swift run`

## Tech notes

- Window discovery: `CGWindowListCopyWindowInfo`
- App metadata + icons: `NSRunningApplication`
- Window focusing: Accessibility API (`AXUIElement`), when trusted
- UI: AppKit (`NSStatusItem`, `NSPopover`, `NSTableView`)

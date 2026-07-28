# Mission Control Buddy 1.0.1

A small but meaningful maintenance release. 🐶

## 🐛 Bug Fixes
- **Title-less windows now get a chip.** Apps that expose an empty window title
  (most notably **TablePlus**, but any app with a blank `AXTitle`) were silently
  skipped and never got an overlay. They now show their **app icon + name**, with
  identity recovered via aspect-ratio matching — and per-window claim tracking so
  no two thumbnails grab the same identity.

## ✨ Improvements
- **Version now shown in About.** The About dialog displays the current version
  (e.g. *"Mission Control Buddy v1.0.1"*), read live from the app bundle so it
  always stays accurate.

## 📝 Docs
- README updated with a direct download link (Installer DMG).

## 📦 Install
Download the DMG, drag to Applications, launch, and grant **Accessibility**
permission (System Settings → Privacy & Security → Accessibility).

**Full changelog:** 1.0.0...1.0.1

# Trackpad Tweaks

Lightweight macOS menu-bar app that remaps trackpad gestures to media controls.

Default preset:
- **4-finger swipe down → Play / Pause**
- **4-finger swipe left → Previous track**
- **4-finger swipe right → Next track**
- 4-finger up → Mute, 3-finger up/down → Volume up/down, 3-finger left/right → Prev/Next

Also available per gesture: **Mission Control** (`^⌥Space`, OmniWM command palette), **App Windows** (`^↓`), **Desktop Left/Right** (OmniWM `switch-workspace prev/next` over IPC — immune to the beep problem below).

> ⚠️ **Desktop Left/Right need OmniWM's IPC server on.** If gestures do nothing and the debug log shows `omniwmctl exit=...`, enable IPC in OmniWM Settings, then retry. (Background: OmniWM ignores *synthesized* hotkeys — a sent `^⌥←` falls through to the focused app, which is the "pong" beep. `omniwmctl` talks to OmniWM directly, so it always works once IPC is on. Your physical keyboard is unaffected either way.)

> ⚠️ Mapping a gesture to Desktop Left/Right duplicates the macOS default for 3/4-finger horizontal swipes. Disable "Swipe between full-screen applications" in System Settings → Trackpad first, or both actions fire and the desktop appears not to move.

All mappings are editable in the Settings window.

## How it works

- **Input:** raw trackpad frames from Apple's private `MultitouchSupport.framework` (the only way to get system-wide touch data — `NSEvent` touches only fire for your own window). Verified working with 1 device on this Mac.
- **Recognition:** `GestureRecognizer` state machine classifies each touch sequence by peak finger count + centroid travel into swipe (direction) or tap, with movement/duration thresholds + cooldown debounce.
- **Output:** synthesizes media keys via `NSEvent.otherEvent(.systemDefined, subtype: 8)` with `NX_KEYTYPE_PLAY (16) / NEXT (17) / PREVIOUS (18) / SOUND_UP / SOUND_DOWN / MUTE`. Requires **Accessibility** permission.

AppKit-only, no SwiftUI — builds with just Command Line Tools, ~420 KB binary, menu-bar (`LSUIElement`) app, negligible CPU (event-driven callbacks only).

## Build & run

```bash
./scripts/make-app.sh        # debug or: ./scripts/make-app.sh release
open TrackpadTweaks.app
```

On first launch grant **Accessibility** so it can send media keys. Click the ⏯ menu-bar icon → Open Settings to remap.

Debug logging:

```bash
TRACKPAD_TWEAKS_DEBUG=1 ./TrackpadTweaks.app/Contents/MacOS/TrackpadTweaks
```

Settings persist to `~/Library/Application Support/TrackpadTweaks/bindings.json`.

## Gesture conflicts

macOS owns 3- and 4-finger swipes by default (Mission Control, spaces, App Exposé). Those rows show ⚠︎. If bound, **both** the system action and your media key fire. Fix by disabling the conflicting gesture in **System Settings → Trackpad**.

## Files

- `Sources/CMultitouch/` — C header for private `MultitouchSupport.framework`
- `Sources/TrackpadTweaks/GestureModels.swift` — Gesture types
- `Sources/TrackpadTweaks/GestureRecognizer.swift` — swipe/tap state machine
- `Sources/TrackpadTweaks/MultitouchReader.swift` — device enumeration, sleep/wake restart
- `Sources/TrackpadTweaks/MediaKeys.swift` — NX_SYSDEFINED media-key synthesis
- `Sources/TrackpadTweaks/SystemShortcuts.swift` — system actions via default key combos (^↑ ^↓ ^← ^→)
- `Sources/TrackpadTweaks/MediaActionStore.swift` — bindings + JSON persistence
- `Sources/TrackpadTweaks/SettingsWindowController.swift` — AppKit settings UI
- `Sources/TrackpadTweaks/AppDelegate.swift` + `main.swift` — menu-bar app

## Limitations

- Unsandboxed, ad-hoc signed — personal use, not App Store distributable.
- Rebuilding may require re-granting Accessibility (macOS tracks bundle id + signature).
- For stable Launch at Login, keep `TrackpadTweaks.app` in `/Applications`.

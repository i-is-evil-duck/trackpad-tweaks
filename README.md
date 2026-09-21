# Trackpad Tweaks

Lightweight macOS menu-bar app that remaps 4-finger trackpad swipes to media controls.

Mappings (editable in Settings):
- **4-finger swipe down → Play / Pause**
- **4-finger swipe left → Previous track**
- **4-finger swipe right → Next track**
- **4-finger swipe up → Mute**

That's it — 4 gestures, 4 media actions, nothing else.

## How it works

- **Input:** raw trackpad frames from Apple's private `MultitouchSupport.framework` (the only way to get system-wide touch data). Frames with anything other than 4 fingers are ignored before any math happens, so normal scrolling costs one integer compare per frame.
- **Recognition:** `GestureRecognizer` accumulates net centroid travel into a swipe in the dominant direction, with a movement threshold + cooldown debounce. No tap detection, no multi-count bookkeeping.
- **Output:** media keys via `NSEvent.otherEvent(.systemDefined, subtype: 8)` with `NX_KEYTYPE_PLAY / NEXT / PREVIOUS / MUTE`. Requires **Accessibility** permission.

AppKit-only (builds with just Command Line Tools), menu-bar (`LSUIElement`) app. Idle footprint is one status item + the multitouch callback thread; the settings window is built on demand and fully released on close. Settings persist to `~/Library/Application Support/TrackpadTweaks/bindings.json`.

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

## Gesture conflicts

macOS owns all 4-finger swipes by default (Mission Control, spaces, App Exposé). If bound, **both** the system action and your media key fire — disable the conflicting gestures in **System Settings → Trackpad**.

## Files

- `Sources/CMultitouch/` — C header for private `MultitouchSupport.framework`
- `Sources/TrackpadTweaks/GestureModels.swift` — 4-finger swipe model
- `Sources/TrackpadTweaks/GestureRecognizer.swift` — swipe state machine
- `Sources/TrackpadTweaks/MultitouchReader.swift` — device enumeration, sleep/wake restart
- `Sources/TrackpadTweaks/MediaKeys.swift` — NX_SYSDEFINED media-key synthesis
- `Sources/TrackpadTweaks/MediaActionStore.swift` — bindings + JSON persistence
- `Sources/TrackpadTweaks/SettingsWindowController.swift` — AppKit settings UI
- `Sources/TrackpadTweaks/AppDelegate.swift` + `main.swift` — menu-bar app

## Limitations

- Unsandboxed, ad-hoc signed — personal use, not App Store distributable.
- Rebuilding may require re-granting Accessibility (macOS tracks bundle id + signature).
- For stable Launch at Login, keep `TrackpadTweaks.app` in `/Applications`.

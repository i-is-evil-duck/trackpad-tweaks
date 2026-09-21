# Trackpad Tweaks  <br />  <img alt="Stargazers" src="https://img.shields.io/github/stars/i-is-evil-duck/trackpad-tweaks?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41">


## Trackpad Tweaks
Lightweight macOS menu-bar app that remaps 4-finger trackpad swipes to media controls.

## Downloads

Download the pre-built app from the [releases](https://github.com/i-is-evil-duck/trackpad-tweaks/releases) page.

| Platform | File |
|----------|------|
| macOS | `TrackpadTweaks-1.0.2.zip` |

## Build from Source

```bash
# Clone the repo
git clone https://github.com/i-is-evil-duck/trackpad-tweaks.git
cd trackpad-tweaks

# Build (requires Swift toolchain or Xcode Command Line Tools)
./scripts/make-app.sh release
```

The app will be at `TrackpadTweaks.app`. Move it to `/Applications` for stable Launch at Login.

## Setup

Default mappings:

- `swipe down`: Play / Pause
- `swipe left`: Previous track
- `swipe right`: Next track
- `swipe up`: Mute

On first launch, grant **Accessibility** permission so the app can send media keys (System Settings > Privacy & Security > Accessibility).

macOS owns 4-finger swipes by default (Mission Control, spaces). Disable the conflicting gestures in System Settings > Trackpad, or both actions fire.

Mappings persist to `~/Library/Application Support/TrackpadTweaks/bindings.json`.

## Usage

Run the app:
```bash
open TrackpadTweaks.app
```

Click the ⏯ menu-bar icon to open Settings and remap the four swipes.

With debug logging:
```bash
TRACKPAD_TWEAKS_DEBUG=1 ./TrackpadTweaks.app/Contents/MacOS/TrackpadTweaks
```

## Views

<img src="https://count.getloli.com/get/@trackpad-tweaks?theme=rule34" />

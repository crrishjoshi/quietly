# Quietly

Quietly is a native macOS utility for muting one app without changing the
system volume or silencing everything else.

## Why I built it

Quietly started from a personal need: I wanted to mute one noisy Mac app while
keeping audio from everything else available. I built it as a focused utility
for that moment rather than as a general audio-production product, and I have
been using it since that initial version. The project was developed with
AI-assisted coding and iterative testing against the real macOS audio stack.

The repository preserves the implementation, product brief, diagnostics, and
test report from that development process.

## What it does

- Detects applications connected to macOS audio.
- Shows which applications are currently producing audio.
- Mutes and restores individual applications without changing master volume.
- Handles WebKit helper processes, including webpage audio in Safari.
- Supports app search, playing/muted filters, pinning, refresh controls, and
  Mute All/Restore All actions.
- Removes active mute sessions when an app disappears or Quietly quits.

Quietly is intentionally narrow: it does not provide per-app volume sliders,
audio recording, effects, or a virtual audio driver.

## Disclaimer

Quietly is a personal, need-driven project created for my own use case rather
than a supported public product. Much of the code and documentation was
developed with AI assistance and may require review, correction, or adaptation
for another Mac. Use it at your own risk, review the source before running it,
and do not rely on it for critical audio, privacy, accessibility, or system
behaviour. No warranty or support is provided.

## Compatibility

| Mac | Result |
| --- | --- |
| macOS 14.2 or later, Apple Silicon | Full per-app mute support |
| macOS 14.2 or later, Intel | Full per-app mute support |
| macOS 13 through 14.1 | App opens in compatibility mode |
| macOS 12 or earlier | Not supported |

Apple introduced `AudioHardwareCreateProcessTap` in macOS 14.2. Quietly uses
that API with `CATapMuteBehavior.muted`; it does not install an audio driver.

## Build and run

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

The app bundle is staged at `dist/Quietly.app`.

## Test

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

The explicit developer directory is useful on Macs where `xcode-select` still
points to the standalone Command Line Tools, whose test module search path can
be incomplete.

## Universal release

```bash
./script/package_release.sh
```

This creates a locally ad-hoc-signed Universal 2 app and zip in `release/`.
Public distribution still requires an Apple Developer ID signature and Apple
notarization.

The app icon is reproducible with:

```bash
./script/generate_icon.sh
```

## Privacy

Quietly creates private Core Audio taps only for selected processes and starts
a discard-only IO client because macOS requires an active reader to enforce a
muted process tap. Audio buffers are immediately discarded without inspection;
Quietly never records, stores, analyzes, or uploads sound. All active sessions
are removed when their app disappears, the user restores audio, or Quietly
quits.

Safari and other WebKit-based apps host webpage audio in separate
`com.apple.WebKit.GPU` processes. Quietly resolves each helper's macOS display
name back to its foreground host app and includes the helper's Core Audio
object in that app's mute session.

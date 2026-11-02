# Quietly — Improved Product Prompt

Build **Quietly**, a polished native macOS utility that lets a person mute and
unmute the sound from one app without changing the Mac's master volume or
affecting other apps.

## Product goal

Make per-app audio control feel as immediate and trustworthy as macOS Control
Center: open Quietly, see the apps connected to audio, and mute only the one
that is distracting.

## Platform and compatibility

- Build with SwiftUI and narrow AppKit/Core Audio bridges.
- The app must launch on macOS 13 Ventura and later.
- Real per-process muting must use Apple's private Core Audio process taps and
  is enabled on macOS 14.2 and later.
- On macOS 13 through 14.1, show an honest compatibility screen instead of a
  fake or nonfunctional mute control.
- Produce a Universal 2 release containing both Apple Silicon and Intel code.
- Do not install a legacy kernel extension or third-party virtual audio driver.

## Core experience

1. Detect apps currently connected to macOS audio and group helper processes
   under their parent app.
2. Show app icon, name, playing/connected state, and mute state.
3. Provide one-click per-app mute and unmute.
4. Include search and All, Playing, Muted, and Pinned filters.
5. Add Mute All and Restore All actions with safe automatic cleanup on quit.
6. Keep restore controls permanently available in the main app window and
   through the Audio menu keyboard command.
7. Persist pinned apps and preferences, but never unexpectedly restore a mute
   after Quietly has quit.
8. Add keyboard menu commands for Mute All, Restore All, and Refresh.

## UI and UX direction

- Native, simple, premium, and calm rather than flashy.
- Use system materials and semantic colors so Light and Dark mode both work.
- Use a soft indigo-to-mint accent; avoid pure-black main backgrounds.
- Keep the main window spacious and readable, with one clear primary action per
  row.
- Explain empty, permission, unsupported-system, and audio-engine error states
  in plain language.
- Keep app-menu command labels short and make the full window the source of
  truth for per-app state.

## Privacy and reliability

- Keep every tap private to the Quietly process.
- Start the minimum discard-only IO client required to activate the mute tap.
  Never inspect, store, analyze, or upload audio samples.
- Include `NSAudioCaptureUsageDescription` with an accurate explanation.
- Destroy each process tap when the app is unmuted, disappears, or Quietly
  terminates.
- Reconcile changed audio process IDs so browser helpers and relaunched apps do
  not silently lose their selected state while Quietly remains open.

## Relevant supporting features

- Launch at Login option.
- Configurable 1, 2, or 5 second app-detection refresh.
- Clear engine status and short success/error notices.
- Universal packaging script with code-sign verification and SHA-256 checksum.
- A project-local Build & Run action for repeatable development.

## Explicit non-goals for this version

- Per-app volume sliders. True attenuation requires capturing, scaling, and
  safely routing audio back to the selected output device; a slider must not be
  shown until that full pipeline exists.
- Audio recording, meters derived from captured samples, EQ, or effects.
- Support for macOS versions before Ventura.
- Claiming App Store readiness before sandbox, signing, permissions, and review
  behavior have been validated with an Apple Developer identity.

## Acceptance criteria

- A supported Mac can mute one audio app while another remains audible.
- Unmuting or quitting Quietly restores normal output.
- Unsupported systems receive a precise macOS 14.2 requirement.
- Light and Dark mode remain readable.
- `swift build` and `swift test` pass.
- The packaged executable contains both `arm64` and `x86_64` slices.

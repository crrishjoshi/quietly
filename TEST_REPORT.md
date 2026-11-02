# Quietly 0.1.2 Test Report

Tested on July 23, 2026 on an Apple Silicon MacBook Pro running macOS 26.5.2.

## Regressions that were fixed

Version 0.1.0 created a muted `CATapDescription`, but did not attach that tap
to an aggregate device or start an IO client. macOS accepted the tap object
without activating the mute path, so the UI changed state while audio could
continue playing.

Version 0.1.1 added the complete Core Audio session:

1. A private process tap with `CATapMuteBehavior.muted`.
2. A private HAL aggregate device containing that tap.
3. A discard-only IO callback on the aggregate device.
4. Active device IO for the lifetime of the mute.
5. Reverse-order cleanup on unmute, app exit, process changes, or Quietly quit.

Version 0.1.1 still missed Safari webpage audio. Safari's visible
`com.apple.Safari` process was connected to Core Audio but not producing the
webpage sound. The active audio belonged to an XPC helper:

- HAL bundle: `com.apple.WebKit.GPU`
- macOS process name: `Safari Graphics and Media`
- Parent process: `launchd`

Because the helper has no Safari parent-process relationship, the original
ownership resolver discarded it. Version 0.1.2 maps WebKit helper display names
back to the longest matching foreground app and groups the helper's AudioObject
into Safari.

## Physical-output integration test

A temporary app bundle played a continuous 997 Hz sine tone through the
MacBook speakers using `ffplay`. Quietly detected it as `Quietly Tone Test`.
The MacBook microphone was sampled for three seconds in each state. A narrow
997 Hz band-pass filter isolated the controlled signal; no microphone audio
was saved.

| State | Measured RMS |
| --- | ---: |
| Before mute | -20.80 dB |
| Muted by Quietly | -30.21 dB |
| After unmute | -20.98 dB |

Result:

- Muting the packaged Universal release reduced the physical speaker
  measurement by approximately 9.4 dB to the measured ambient band level.
- Unmuting restored the signal to within approximately 0.2 dB of the baseline.
- The test tone process was stopped after the measurement.

## Safari integration test

A local test page started a continuous 997 Hz `AudioContext` inside an actual
Safari tab. The HAL diagnostic confirmed that `com.apple.WebKit.GPU`, not the
Safari shell process, was producing audio. Quietly displayed Safari as
`Playing now · 2 audio processes` and included both objects in the mute session.

| Safari state | Measured RMS |
| --- | ---: |
| Before mute | -20.19 dB |
| Muted by Quietly | -50.98 dB |
| After unmute | -19.24 dB |

The Safari AudioContext remained `running` during the mute, proving that
Quietly suppressed output rather than pausing the webpage. The physical speaker
measurement dropped by approximately 30.8 dB and returned to within
approximately 1 dB of the baseline. No microphone audio was saved. The tone was
stopped and the temporary Safari tab was closed afterward.

The final packaged-release regression also verified the authoritative
`coreaudiod` lifecycle: both `com.apple.Safari` and
`com.apple.WebKit.GPU` received `AddMuter` events from Quietly, and both
received `RemoveMuter` events during cleanup while the page's AudioContext
remained `running`. macOS stops exposing the target app to Accessibility
automation while the system-audio tap is active; WindowServer inspection
confirmed the real Quietly window remained on-screen throughout.

## Automated checks

- Swift build with warnings treated as errors.
- Swift Testing suite: 4 tests, including WebKit helper-name ownership.
- App bundle launch and process verification.
- Universal 2 packaging for `arm64` and `x86_64`.
- App bundle signature verification.
- SHA-256 verification for the release zip.

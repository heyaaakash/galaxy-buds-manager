# Galaxy Buds2 Pro Manager for macOS

A native menu-bar manager for Samsung Galaxy Buds2 Pro (SM-R510), requiring macOS 14 or newer. This is a macOS companion, not an Android application or a complete replacement for Galaxy Wearable.

## Connect

1. Pair the earbuds in **System Settings → Bluetooth**.
2. Open their case or wear them, and allow the app Bluetooth access.
3. Launch the app. **Settings → General → Connect automatically** controls startup, wake, and reconnect behavior. It defaults to enabled on a fresh install and preserves existing preferences.
4. If automatic connection is disabled, select **Connect** in the menu.

Discovery uses macOS paired devices and system connection notifications. Configuration uses the Samsung service UUID `2e73a4ad-332d-41fc-90e2-16bef06523f2`, resolved through SDP. Audio remains managed by macOS. Renamed earbuds are remembered by address after a successful connection; unrelated Buds models are excluded from automatic name matching.

Disconnect/Cancel suppresses automatic reconnection until an explicit Connect or re-enabling automatic connection. Bluetooth power changes and sleep/wake are handled separately. Settings remain disabled until a valid extended device snapshot arrives. Commands update the UI when the earbuds confirm them; timeouts and Bluetooth errors are shown in the menu.

## Controls

- Live left/right/case battery, wearing state, and charging data
- ANC, ambient, Off, noise control with one earbud
- Ambient volume, firmware-gated extra-high ambient, separate ambient levels and tone
- Six EQ presets, stereo balance, gaming-mode setting
- Touch lock, individual tap/hold/call gestures, long-press actions, double-tap edge volume
- Voice Detect with 5/10/15-second timeout, sidetone, firmware-gated clear call sound
- Seamless connection setting
- Nearby earbud ringing and per-earbud mute; ringing is blocked while a bud is detected in-ear
- Fit test with cancellation and timeout; both earbuds must be worn
- Firmware, serials, device colors, diagnostic requests, and exportable protocol logs
- Reboot, power off, and factory reset, each behind a confirmation

Samsung-specific host features (360 Audio rendering, SSC codec, notification reading, SmartThings location finding) are not implemented by this Mac app. Firmware updates and rename still require Galaxy Wearable. Unsupported adaptive-volume and one-earbud media-pause toggles were removed rather than presented as functioning settings. Spotify/assistant touch actions depend on the connected host. Protocol support alone does not guarantee a feature's effect on macOS audio.

See [the capability and validation notes](Docs/CAPABILITY_MATRIX.md) for the distinction between implemented, physically checked, and unverified functionality.

## Build and run

With a working Swift toolchain / macOS SDK:

```sh
./run.sh
```

This incrementally builds, bundles, ad-hoc signs, and launches the app. It always checks source changes, preventing stale binaries. To build a release app and DMG:

```sh
./build_app.sh
```

`SDKROOT`, `SWIFT_BUILD_PATH`, `CONFIGURATION` (debug/release), and `SKIP_DMG=1` are supported overrides. For example, this machine's macOS 27 SDK was missing a SwiftUI compiler plugin, so verification used its installed macOS 26.5 SDK:

```sh
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ./run.sh
```

Run the app bundle rather than a bare `swift run` executable so macOS can associate Bluetooth permission with its bundle identity. Ad-hoc signing is for local development; this build is not notarized for distribution.

## Tests and diagnostics

```sh
swift test
```

`RegressionTests.swift` uses Swift Testing (Swift 6+), including a known CRC vector, corrupted/split frames, real-model status layouts, revision boundaries, command acknowledgement and cleanup, and bounded diagnostic decoders. Legacy XCTest tests also run where XCTest is installed. Check the test count: a toolchain without either framework cannot validate the tests.

If the Command Line Tools build engine omits its installed Testing plugin:

```sh
swift test --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

Enable protocol logging in Settings → Advanced, or launch the bundle with `--protocol-log` for session-only diagnostic output. Logs are bounded in memory and available in the menu; export explicitly to save them. Logs can include device addresses and serial numbers, so review them before sharing.

Protocol facts were checked against [GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient), including its SM-R510 model specification, decoders, and command layouts. This app is not affiliated with Samsung.

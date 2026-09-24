# Galaxy Buds2 Pro Manager for macOS

A native menu-bar manager for Samsung Galaxy Buds, requiring macOS 14 or newer. Galaxy Buds2 Pro (SM-R510) has the full set of controls. Other recognized non-legacy models have an experimental battery-only mode; their settings controls are disabled until model-specific protocols are verified. This is a macOS companion, not an Android application or a complete replacement for Galaxy Wearable.

## Connect

1. Pair the earbuds in **System Settings → Bluetooth**.
2. Open their case or wear them, and allow the app Bluetooth access.
3. Launch the menu-bar app and click the earbuds icon. Connect the earbuds to this Mac in **System Settings → Bluetooth** (or via the Control Center); the app attaches automatically as soon as macOS connects them.
4. The **Attach** action only works after macOS shows the earbuds as connected. Connect the Bluetooth device in macOS first.

Discovery uses macOS paired devices and system connection notifications. Configuration resolves the model's Samsung service UUID through SDP: the newer UUID `2e73a4ad-332d-41fc-90e2-16bef06523f2` or standard SPP for Buds+, Buds Live, and Buds Pro. Audio remains managed by macOS. A renamed Buds2 Pro is remembered by address after a successful connection. Other Galaxy Buds names are shown in the paired-device list; models with an unverified protocol are labeled and cannot be opened by the app.

The app classifies each macOS Bluetooth connection notification using the device's cached name or model code, then attaches only to recognized Galaxy Buds on an existing system connection. It never intentionally initiates or retries a Bluetooth connection to a disconnected device; manual Attach also requires an existing system connection. If the earbuds are connected to another device (e.g. a phone), or you disconnect them manually, the app stays idle until macOS connects them to this Mac again. Bluetooth power changes and sleep/wake only re-check whether macOS already has the earbuds connected. Buds2 Pro settings remain disabled until a valid extended device snapshot arrives. Battery-only profiles send no setting commands and display only the shared battery and placement fields from incoming status messages. Commands on Buds2 Pro update the UI when the earbuds confirm them; timeouts and Bluetooth errors are shown in the menu.

Settings → Bluetooth shows the most recently observed device name and whether the app recognized it as Galaxy Buds. Identification uses locally cached Bluetooth information; a renamed model with no recognizable name or remembered address may be shown as an unrelated device.

## Controls

The connected-device menu shows battery levels, a quick ANC/Ambient/Off switch, and grouped Sound and Utilities pages. The complete main menu fits without scrolling. The footer opens Settings and Device Info; More contains the protocol log and Quit. Detail pages keep Back visible and scroll only when their controls exceed the available space. **Settings** has General, Bluetooth, Device, and Advanced sections. Device controls stay unavailable until the earbuds send their settings; connection and app settings remain accessible.

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

See [the capability and validation notes](Docs/CAPABILITY_MATRIX.md) for the model support levels and the distinction between implemented, physically checked, and unverified functionality.

## Build and run

With a working Swift toolchain / macOS SDK:

```sh
./run.sh
```

This incrementally builds, bundles, ad-hoc signs, and launches the app. It checks source changes before launch. To build a release app and DMG:

```sh
./build_app.sh
```

The release deliverables are `dist/Galaxy Buds2 Pro Manager.app` and `dist/GalaxyBuds2-Pro-Manager.dmg`. Open the DMG and drag the app to Applications. `.build/` contains disposable compiler output and packaging staging. `./run.sh` uses a temporary debug app in `.build/` and does not replace the release app in `dist/`.

`SDKROOT`, `SWIFT_BUILD_PATH`, `CONFIGURATION` (debug/release), `APP_OUTPUT_DIR`, and `SKIP_DMG=1` are supported build overrides. If the active SDK or debug-symbol generator causes a build failure, select an installed SDK and optionally omit debug symbols with `GBM_DEBUG_INFO_FORMAT=none`:

```sh
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
GBM_DEBUG_INFO_FORMAT=none ./build_app.sh
```

Run the app bundle rather than a bare `swift run` executable so macOS can associate Bluetooth permission with its bundle identity. The script uses the macOS `sips`, `iconutil`, `codesign`, and `hdiutil` tools. Its ad-hoc signature is for local use; the DMG is not notarized for distribution.

## Tests and diagnostics

```sh
swift test
```

`RegressionTests.swift` uses Swift Testing (Swift 6+), including a known CRC vector, corrupted/split frames, real-model status layouts, revision boundaries, command acknowledgement and cleanup, and bounded diagnostic decoders. Legacy XCTest tests also run where XCTest is installed. Check the test count: a toolchain without either framework cannot validate the tests.

If the Command Line Tools build engine omits its installed Testing plugin, pass its plugin path. On systems where debug-symbol generation is blocked, add `-debug-info-format none`:

```sh
swift test --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -debug-info-format none \
  -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

Enable protocol logging in Settings → Advanced, or launch the bundle with `--protocol-log` for session-only diagnostic output. Logs are bounded in memory and available in the menu; export explicitly to save them. Logs can include device addresses and serial numbers, so review them before sharing.

Protocol facts were checked against [GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient), including its SM-R510 model specification, decoders, and command layouts. This app is not affiliated with Samsung.

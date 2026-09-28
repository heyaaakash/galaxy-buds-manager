# Galaxy Buds Manager for macOS

A menu bar app for Samsung Galaxy Buds on macOS 14 or newer. Galaxy Buds2 Pro (SM-R510) has battery status, settings, and diagnostics. Support for other models is experimental.

This is an independent project, unaffiliated with Samsung. The app appears in macOS as **Galaxy Buds2 Pro Manager**.

## Download

Get the latest DMG from [Releases](https://github.com/heyaaakash/galaxy-buds-manager/releases/latest). Choose `arm64` for an Apple Silicon Mac or `x86_64` for an Intel Mac. Open the DMG and drag the app to Applications.

The DMGs are ad-hoc signed and **not notarized**. If macOS blocks the first launch and you trust the download, try opening the app, then use **System Settings → Privacy & Security → Open Anyway**. See [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Each release includes `SHA256SUMS.txt` so you can check the download.

## Compatibility

| Earbuds | Support |
|---|---|
| Galaxy Buds2 Pro (SM-R510) | Battery, controls, and diagnostics; tested with one physical device |
| Buds+, Buds Live, Buds Pro, Buds2, Buds FE, Buds3, Buds3 Pro | Experimental battery and placement display; no settings controls or physical-device testing in this project |
| Original Galaxy Buds and other models | Detection only; app connection disabled |

Recognition does not guarantee that a model will send battery data. See the [capability matrix](Docs/CAPABILITY_MATRIX.md) for feature limits and test evidence.

## Use the app

1. Pair and connect your earbuds in **System Settings → Bluetooth**.
2. Open their case or wear them, then launch the app and allow Bluetooth access.
3. Click the earbuds icon in the menu bar. The app attaches when macOS has connected the earbuds.

The app does not connect disconnected earbuds for you. If **Attach** is unavailable, connect them in macOS first. Audio output remains under macOS control.

On Buds2 Pro, the app offers battery levels, ANC and ambient controls, EQ, touch settings, Voice Detect, a fit test, ringing, and diagnostics. Reboot, power-off, and factory reset require confirmation. Some controls depend on firmware; see the [capability matrix](Docs/CAPABILITY_MATRIX.md). Firmware updates, renaming, Samsung 360 Audio, and SmartThings location are not provided by this app.

## Build from source

On a Mac with a working Swift toolchain and macOS SDK:

```sh
git clone https://github.com/heyaaakash/galaxy-buds-manager.git
cd galaxy-buds-manager
swift test
./run.sh          # Build and launch a local debug app
./build_app.sh    # Create an app and DMG in dist/
```

Run the app bundle rather than a bare `swift run` executable so macOS can associate Bluetooth permission with the app. See [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a code change.

## Privacy and license

The app stores the last observed Buds name and Bluetooth address plus preferences on your Mac. It has no telemetry or network service. Exported protocol logs may contain device addresses or serial numbers; remove those before sharing.

The source is [GPL-3.0-only](LICENSE). Protocol facts were checked against the GPLv3-licensed [GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient); this Swift implementation was written for this app.

Copyright © 2026 Aakash Rohilla.

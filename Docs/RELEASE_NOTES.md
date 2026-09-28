# Galaxy Buds Manager v1.0.0

First public macOS download. Requires macOS 14 or newer.

## Downloads

- `GalaxyBudsManager-v1.0.0-macos-arm64.dmg` — Apple Silicon Macs
- `GalaxyBudsManager-v1.0.0-macos-x86_64.dmg` — Intel Macs
- `SHA256SUMS.txt` — SHA-256 checksums for both DMGs

Open the DMG and drag **Galaxy Buds2 Pro Manager** to Applications. These builds are **ad-hoc signed and not notarized**. macOS may block the first launch because there is no Apple Developer ID certificate. If you trust the downloaded app, try opening it, then use **System Settings → Privacy & Security → Open Anyway**. See [Apple's guidance](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Do not disable Gatekeeper globally.

## Support and validation

Galaxy Buds2 Pro (SM-R510) has battery information, settings controls, and diagnostics. One physical Buds2 Pro device was tested; individual features have different validation levels. Buds+, Buds Live, Buds Pro, Buds2, Buds FE, Buds3, and Buds3 Pro have experimental incoming battery and placement display only, with no physical-device validation in this project. Other models are detection only. See the [capability matrix](https://github.com/heyaaakash/galaxy-buds-manager/blob/v1.0.0/Docs/CAPABILITY_MATRIX.md) for details.

The automated protocol tests and packaging checks run on both Apple Silicon and Intel macOS runners. A clean-Mac installation test and physical-device validation on Intel have not yet been recorded.

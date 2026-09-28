# Contributing

Thanks for helping improve Galaxy Buds support on macOS.

## Before opening a change

- Check the [capability matrix](Docs/CAPABILITY_MATRIX.md) for the model and feature involved.
- Open an issue for a new model or wire command before implementing it. Include the model number, firmware version, macOS version, and what you verified on physical hardware.
- Remove Bluetooth addresses, serial numbers, and other identifying data from logs before posting them.

## Development

This is a Swift Package targeting macOS 14 or newer. Run `swift test` for protocol regressions. Run `./build_app.sh` to package a local app and DMG. The script's default ad-hoc signature is for local testing; public downloads require Developer ID signing and notarization.

Keep protocol handling specific to each model. Never send Buds2 Pro (SM-R510) setting commands to another model. Attach only after macOS reports that the device is connected, and recheck the system connection before SDP or RFCOMM calls. Tests should cover any new protocol framing, decoder, or command behavior.

Update the capability matrix and README when support or validation changes. Distinguish code paths inferred from public protocol documentation from behavior checked on a physical device.

## Pull requests

Describe the affected model, evidence of hardware testing, user-visible behavior, and tests run. Avoid committing build output, DMGs, protocol logs, device identifiers, or signing material.

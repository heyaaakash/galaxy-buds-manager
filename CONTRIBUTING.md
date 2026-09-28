# Contributing

Issues and pull requests are welcome. For a new earbud model or protocol command, open an issue first. Include the model number, firmware and macOS versions, and what you checked on physical hardware. Remove Bluetooth addresses, serial numbers, and other identifying data from logs before sharing them.

For code changes, run `swift test` and `./build_app.sh`. Keep protocol commands specific to each model; never send Buds2 Pro settings commands to another model. Attach only after macOS reports the earbuds connected, and recheck before SDP or RFCOMM calls. Update the [capability matrix](Docs/CAPABILITY_MATRIX.md) when support or validation changes; distinguish code based on protocol references from behavior tested on hardware.

In a pull request, describe the user-visible change, models affected, tests run, and any hardware checks. Do not commit build output, DMGs, logs, device identifiers, or signing credentials.

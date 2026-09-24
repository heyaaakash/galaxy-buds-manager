# Galaxy Buds compatibility and validation

## Model support

| Models | Current behavior | Validation |
|---|---|---|
| Galaxy Buds2 Pro (SM-R510) | Full existing controls and diagnostics | Physically checked on one device; details below |
| Galaxy Buds+, Buds Live, Buds Pro | Standard SPP connection; incoming battery and placement only | Based on the shared status prefix in GalaxyBudsClient; no physical device test in this project |
| Galaxy Buds2, Buds FE, Buds3, Buds3 Pro | New Samsung SPP connection; incoming battery and placement only | Based on the shared status prefix in GalaxyBudsClient; no physical device test in this project |
| Original Galaxy Buds and other models | Detected by name, with connection disabled | Their framing or status behavior needs a separate implementation |

Battery-only profiles do not send handshakes, acknowledgements, or setting commands. They rely on an incoming status notification after the RFCOMM channel opens. If the model needs an active handshake, the app will connect but show no battery data. Connecting and status delivery must be tested on actual hardware before claiming verified support. Model names are used to choose a profile, so renamed non-SM-R510 earbuds may need their original Bluetooth name to be recognized.

The model-specific service UUIDs and shared status prefix were cross-checked against [GalaxyBudsClient device specifications](https://github.com/timschneeb/GalaxyBudsClient/tree/master/GalaxyBudsClient/Model/Specifications), [basic status decoder](https://github.com/timschneeb/GalaxyBudsClient/blob/master/GalaxyBudsClient/Message/Decoder/StatusUpdateDecoder.cs), and [extended status decoder](https://github.com/timschneeb/GalaxyBudsClient/blob/master/GalaxyBudsClient/Message/Decoder/ExtendedStatusUpdateDecoder.cs).

## Buds2 Pro full-control profile

Target: Samsung SM-R510, macOS 14+. The device's extended-status revision determines optional fields; unknown newer tails are ignored and truncated mandatory fields are rejected.

## Implemented controls

| Capability | Implementation / limits |
|---|---|
| Detection | Paired Buds2 Pro names, saved address, macOS connect notification; no pairing bypass |
| Connection | Samsung configuration-service UUID via SDP; asynchronous channel opening with timeout and stale-callback rejection |
| Attachment model | Classifies every macOS classic Bluetooth connect notification from cached device information; attaches only after macOS reports a supported Buds model connected. Manual Attach has the same requirement. SDP and RFCOMM are checked against the live system connection immediately before use. |

| Battery | L/R/case, unavailable levels shown as unknown; charging from extended revision 11+ or basic status revision 1+ |
| Noise control | Off / ANC / ambient; universal ACK or matching noise notification confirms a change |
| Ambient | Base volume 0–2; extra-high option revision 13+, extra step 3; customization per side and tone |
| Equalizer | Normal, Bass Boost, Soft, Dynamic, Clear, Treble Boost |
| Balance | 0–32, center 16 |
| Touch | Modern multi-byte lock payload preserving gesture flags, valid long-press mapping, per-tap/call flags, edge double-tap volume |
| Voice Detect | Enable, 5/10/15-second duration, confirmed by device |
| Calls | Sidetone; extra clear call sound revision 13+ |
| Seamless connection | Inverted wire boolean; effect depends on connected hosts |
| Gaming setting | Uses adjust-sound-sync command; does not change the Mac's codec support |
| Ringing | Start/stop/mute, no in-ear start, stop on leaving its screen |
| Fit test | Start/stop payloads, good/bad/error decode, 20-second timeout and both-ear requirement |
| Information | Compact firmware decode, fixed-width earbud/cradle serials, colors, raw diagnostics, cycle counts |
| Device actions | Reset/reboot/power off require explicit UI confirmation; not automatically retried |
| Logs | Synchronized bounded storage, text/JSON export, RX-only replay extraction |

Apple documents that [SDP](https://developer.apple.com/documentation/iobluetooth/iobluetoothdevice/performsdpquery%28_%3A%29) and [RFCOMM](https://developer.apple.com/documentation/iobluetooth/iobluetoothdevice/openrfcommchannelasync%28_%3Awithchannelid%3Adelegate%3A%29) can establish a Bluetooth baseband link if it has dropped. The checks above prevent deliberate connection attempts to disconnected devices, but a disconnect between the final check and the framework call is still possible. Avoiding that race entirely would require disabling the settings channel and therefore live Buds status and controls.

## Not implemented as Mac features

Firmware updates, alternate-protocol rename, Samsung 360 Audio rendering/head tracking integration, Samsung Seamless Codec, phone notification reading, and SmartThings cloud location finding. Adaptive-volume/custom-EQ capability claims from other Buds models do not establish SM-R510 support. Those are not exposed as working controls.

## Validation performed on 2026-09-18

The locally built app connected over channel 27 to physical Buds2 Pro reporting extended-status revision 14. Live left/right/case battery and settings populated the menu. EQ Soft → Dynamic → Soft and Voice Detect off → on → off were confirmed by device acknowledgements. ANC enable was acknowledged; the initial Off request lacked a direct ACK, motivating support for matching noise-status confirmation. No reset, reboot, firmware flashing, or power-off was executed.

Automated tests cover packet correctness, revision layouts/truncation, fit-result semantics, modern touch payloads, clamping, session reset, unknown IDs, JSON/replay, queue replacement/retry cleanup, and notification matching. This is not evidence that every firmware revision or every additional control has been physically tested. Sleep/wake across hardware and OS versions, custom ambient, balance, touch gesture edits, ringing, and destructive commands need additional device validation.

## Wire details

- Standard frame: `FD`, two-byte size/flags, raw message ID, payload, little-endian CRC, `DD`.
- CRC polynomial `0x1021`, initial value **0**; covers ID plus payload. Corrupt frames are rejected.
- Universal command acknowledgement ID: `0x42`; its first payload byte identifies the acknowledged command.
- Extended status `0x61` is model-specific. Buds2 Pro battery offsets are 2/3/7, EQ 9, packed touch flags/actions 10/11, and noise mode 12.
- Basic status `0x60` battery offsets are 1/2/6. The two layouts must not be confused.
- Fit result 1 means good, 0 means poor, 2 means test failed.

Reference: [GalaxyBudsClient source](https://github.com/timschneeb/GalaxyBudsClient/tree/master/GalaxyBudsClient). Implementations here were written for this Swift app using protocol facts checked against that reference and local device traffic.

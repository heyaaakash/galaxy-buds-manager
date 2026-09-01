# Galaxy Buds2 Pro Protocol Capability Matrix

> **Model**: Samsung Galaxy Buds2 Pro (SM-R510)  
> **Bluetooth Version**: 5.3  
> **Protocol**: Classic Bluetooth SPP (RFCOMM) with binary framing  
> **Reference**: [GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient) (GPLv3 — used as reference only, not copied)

## Packet Format

```
┌─────┬──────────┬─────────┬─────────┬──────────┬─────┐
│ SOM │ Header   │ MsgID   │ Payload │ CRC16    │ EOM │
│ 1B  │ 2B       │ 1B      │ N bytes │ 2B       │ 1B  │
│ 0xFD│          │         │         │ CCITT    │ 0xDD│
└─────┴──────────┴─────────┴─────────┴──────────┴─────┘
```

- **SOM**: Start of Message = `0xFD`
- **Header**: 2 bytes — 11-bit payload size, response flag, fragment flag
- **CRC16**: CRC-CCITT over `[MsgID] + [Payload]`, init=0xFFFF, poly=0x1021

## Feature Support (Buds2 Pro)

| Feature | Supported | Min FW Rev | Notes |
|---------|-----------|------------|-------|
| Noise Control (ANC/Ambient/Off) | ✅ | — | 3 modes |
| ANC with One Earbud | ✅ | — | |
| Ambient Sound | ✅ | — | Max volume = 2 |
| Ambient Extra Loud | ✅ | Rev 13 | |
| Ambient Sidetone | ✅ | Rev 1 | |
| Ambient Customize (3-band) | ✅ | — | |
| Equalizer (5 presets) | ✅ | — | Bass Boost, Soft, Dynamic, Clear, Treble Boost |
| Custom Equalizer | ✅ | — | Per-band curve |
| Touchpad Lock | ✅ | — | |
| Advanced Touch Lock | ✅ | — | |
| Touch Lock for Calls | ✅ | Rev 1 | |
| Long-Press Actions | ✅ | — | Voice Assistant, Volume, Ambient, Noise Control |
| Find My Earbuds | ✅ | — | Beep sound + mute control |
| Spatial Audio | ✅ | — | With head tracking |
| Head Tracking | ✅ | Rev 8 | |
| Game Mode (Low Latency) | ✅ | — | |
| Detect Conversations | ✅ | — | |
| Sidetone (Calls) | ✅ | — | |
| In-Band Ringtone | ✅ | — | |
| Voice Notification | ✅ | — | |
| Bixby Wake-Up | ✅ | — | |
| Auto Adjust Sound | ✅ | Rev 3 | |
| Adaptive Volume | ✅ | — | |
| Adaptive EQ | ✅ | — | |
| Seamless Connection | ✅ | — | |
| Stereo Pan | ✅ | — | |
| Double Tap Volume | ✅ | — | |
| Extra Clear Call Sound | ✅ | Rev 13 | |
| Call Path Control | ✅ | Rev 1 | |
| Pause Media on Removal | ✅ | — | |
| Charging State | ✅ | Rev 11 | |
| Case Battery | ✅ | — | |
| Device Color | ✅ | — | |
| Rename | ✅ | — | |
| Cradle Serial Number | ✅ | — | |
| SmartThings Find | ✅ | — | |
| Usage Report | ✅ | — | |
| Firmware Updates (FOTA) | ⚠️ | — | Complex protocol, needs empirical testing |
| Debug Data | ✅ | — | Serial number, build info, SKU |
| Factory Reset | ✅ | — | Destructive! |
| Reboot | ✅ | — | |
| Multipoint | ✅ | — | Multi-device connection |

## Readable Commands

These commands can be sent to request data from the device:

| MsgID | Name | Response | Notes |
|-------|------|----------|-------|
| 0x63 | VERSION_INFO | Firmware version string | Short format |
| 0x68 | VERSION_INFO_LONG | Firmware version string | Extended format |
| 0x29 | DEBUG_SERIAL_NUMBER | Serial numbers (L/R) | |
| 0x28 | DEBUG_BUILD_INFO | Build info strings | |
| 0x22 | DEBUG_SKU | SKU data | May return zeros |
| 0x26 | DEBUG_GET_ALL_DATA | All sensor data | Debug only |
| 0x24 | DEBUG_GET_VERSION | Version data | |
| 0x94 | BATTERY_TYPE | Battery type strings | May return zeros |
| 0xAB | SELF_TEST | Self-test results | Disconnects buds! |
| 0x9D | CHECK_FIT_OF_EARBUDS | Fit check result | |
| 0xD9 | ADAPTIVE_EQ_STATUS | Adaptive EQ state | |

## Writable Commands

These commands send configuration to the device:

| MsgID | Name | Payload | Response |
|-------|------|---------|----------|
| 0x88 | MANAGER_INFO | App info (3 bytes) | None |
| 0xA7 | UPDATE_TIME | Timestamp (12 bytes) | None |
| 0x78 | NOISE_CONTROLS | Mode byte (0/1/2) | Update notification |
| 0x80 | SET_AMBIENT_MODE | Enable byte | Update notification |
| 0x84 | AMBIENT_VOLUME | Volume (0-2) | Update notification |
| 0x82 | CUSTOMIZE_AMBIENT | 3-band levels | |
| 0x83 | NOISE_REDUCTION_LEVEL | Level byte | |
| 0x96 | EXTRA_HIGH_AMBIENT | Enable byte | |
| 0x86 | EQUALIZER | Preset (0-5) | |
| 0x89 | CUSTOM_EQUALIZE_SEND | EQ curve data | |
| 0x90 | LOCK_TOUCHPAD | Enable byte | Update notification |
| 0x92 | SET_TOUCHPAD_OPTION | Left/Right actions | Update notification |
| 0xA0 | FIND_MY_EARBUDS_START | None | |
| 0xA1 | FIND_MY_EARBUDS_STOP | None | |
| 0xA2 | MUTE_EARBUD | Left/Right mute | Status update |
| 0x7C | SET_SPATIAL_AUDIO | Enable byte | |
| 0x87 | GAME_MODE | Enable byte | |
| 0x7A | SET_DETECT_CONVERSATIONS | Enable byte | |
| 0x8B | SET_SIDETONE | Enable byte | |
| 0x8A | SET_IN_BAND_RINGTONE | Enable byte | |
| 0xA4 | VOICE_NOTI_STATUS | Enable byte | |
| 0xC5 | SET_ADAPTIVE_VOLUME | Enable byte | |
| 0x50 | RESET | None | DESTRUCTIVE |
| 0x52 | REBOOT | None | |
| 0x53 | POWEROFF | None | |

## Protocol Flow

### Connection Sequence

```
1. macOS connects to device via RFCOMM (SPP UUID)
2. Device automatically sends EXTENDED_STATUS_UPDATED (0x61)
3. Client sends MANAGER_INFO (0x88) as acknowledgement/handshake
4. Client sends UPDATE_TIME (0xA7) to sync clock
5. Client optionally requests VERSION_INFO, SERIAL_NUMBER
6. Connection is ready for commands
```

### Status Update Response

The client must respond to `EXTENDED_STATUS_UPDATED` with:
1. A zero-byte response (ACK) with the same message ID
2. Followed by `MANAGER_INFO` with client type information

## macOS Limitations

| Capability | Status | Notes |
|-----------|--------|-------|
| RFCOMM/SPP | ✅ via IOBluetooth | Not available in CoreBluetooth (BLE only) |
| Device Discovery | ✅ via CoreBluetooth | BLE scanning works for finding devices |
| Pairing | ⚠️ System Settings | Must pair manually first in System Settings |
| A2DP Audio | ✅ System-level | Handled by macOS Bluetooth stack automatically |
| BLE GATT | ⚠️ Limited | Samsung uses classic SPP, not BLE GATT |
| Sandbox | ⚠️ Limited | IOBluetooth has sandbox restrictions |
| Launch at Login | ⚠️ Manual | Requires SMLoginItemSetEnabled or LaunchAgent |

## Uncertain / Needs Testing

| Feature | Status | Notes |
|---------|--------|-------|
| FOTA (Firmware Update) | Unknown | Complex multi-step protocol |
| Custom Ambient Curve | Needs testing | Exact payload format unclear |
| Multipoint control | Needs testing | May need newer FW |
| Adaptive EQ details | Needs testing | Payload format undocumented |
| Spatial Audio data stream | Needs testing | Continuous head tracking data |
| Hidden debug commands | Needs testing | 0x12, 0x13, etc. |

## Debugging

Use the built-in protocol logger (Debug Log tab) to:
1. Capture all raw protocol traffic
2. Export logs as text or JSON
3. Replay captured packets for testing
4. Verify command responses

All commands are logged with:
- Timestamp (ms precision)
- Direction (TX/RX)
- Message ID (human-readable name)
- Payload hex dump
- Decoded fields (where applicable)

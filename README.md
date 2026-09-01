# Galaxy Buds2 Pro Manager for macOS

> *"AirPods controls, but for Galaxy Buds2 Pro on Mac."*

A lightweight, native macOS **menu-bar utility** that provides a complete AirPods-like experience for Samsung Galaxy Buds2 Pro. Built with Swift + SwiftUI + CoreBluetooth/IOBluetooth — no Electron, no bloat, no background processes.

---

## Screenshots

The app lives entirely in the macOS menu bar. Click the earbuds icon to reveal a compact popover with battery levels, noise control, and quick access to all settings.

```
┌──────────────────────────────┐
│  Galaxy Buds2 Pro    ● 90%   │
├──────────────────────────────┤
│  Left          92%           │
│  Right         89%           │
│  Case          76%           │
├──────────────────────────────┤
│  [ ANC ] [ Ambient ] [ Off ] │
├──────────────────────────────┤
│  Equalizer        Dynamic ›  │
│  Touch Controls            › │
│  Voice Detect       ON      │
│  Find My Earbuds           › │
├──────────────────────────────┤
│  Settings                   › │
└──────────────────────────────┘
```

---

## Features

| Category | What's included |
|----------|----------------|
| **Battery** | Left, Right, Case levels with percentages. Charging state. Battery type & cycle count (diagnostics). |
| **Noise Control** | ANC / Ambient / Off switch. Ambient volume (0–2). Extra High Ambient. One-earbud ANC. |
| **Equalizer** | 6 presets: Normal, Bass Boost, Soft, Dynamic, Clear, Treble Boost. Game Mode (low latency). |
| **Touch Controls** | Lock/unlock touchpad. Customizable long-press action per earbud (6 options each). |
| **Voice & Calls** | Voice Detect (auto Ambient on conversation). Sidetone. In-Band Ringtone. Adaptive Volume. |
| **Find My Earbuds** | Start/stop beeping. Mute individual earbuds during search. |
| **Fit Test** | Earbud seal test with pass/fail per ear. |
| **Device Info** | Name, firmware, serial number, cradle serial, color, wearing state, build info, SKU. |
| **Advanced** | Reboot, Power Off, Factory Reset (with confirmation). Debug data reader. Battery cycles. Protocol log export. |
| **Settings** | Auto-reconnect. Launch at login. Show battery in menu bar. Protocol logging. Device management. |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│          UI Layer (SwiftUI)                  │
│  MenuBarPopover → Feature Sheets            │
│  Settings → Tabs (General/Bluetooth/Device) │
├─────────────────────────────────────────────┤
│        AppState (Coordinator)               │
│  Auto-reconnect, onboarding, state restore  │
├─────────────────────────────────────────────┤
│      Protocol Layer (BudsProtocol)          │
│  Message encode/decode, command queue       │
│  Decoders (extended status, version, etc.)  │
│  Encoders (noise control, EQ, touch, etc.)  │
├─────────────────────────────────────────────┤
│        Device Model (DeviceState)           │
│  30+ properties, @Published / Observable    │
├─────────────────────────────────────────────┤
│      Bluetooth Layer (BluetoothManager)     │
│  CoreBluetooth (BLE discovery)              │
│  IOBluetooth RFCOMM (SPP data channel)      │
└─────────────────────────────────────────────┘
```

### How It Works

1. **Discovery** — CoreBluetooth scans for nearby BLE peripherals. The Galaxy Buds2 Pro advertise their presence over BLE even though data flows over classic Bluetooth SPP/RFCOMM.

2. **Connection** — Once paired in macOS System Settings, the app connects via IOBluetooth RFCOMM using the Samsung SPP service UUID (`00001101-0000-1000-8000-00805F9B34FB`).

3. **Handshake** — The earbuds send an `EXTENDED_STATUS_UPDATED` (0x61) message on connect with full device state. The app responds with `MANAGER_INFO` (0x05) to complete the handshake.

4. **State Sync** — All state (battery, wearing, ANC mode, EQ, etc.) is pushed by the device. The app does not poll — it reacts to incoming messages. The only outbound queries are for firmware version, serial number, and debug data at connect time.

5. **Commands** — User actions (change ANC, EQ preset, etc.) send encoded messages through a `CommandQueue` actor with 5-second timeout and 2 retries. Each command is tracked by message ID.

### Project Structure

```
galaxy-buds-2-pro-manager/
├── Package.swift                  # Swift Package Manager manifest
├── build_app.sh                   # One-command build → .app → .dmg
├── app-icon.png                   # App icon source (used for .icns)
├── menubar-icon.png               # Menu bar icon (loaded at runtime)
├── Resources/
│   └── Info.plist                 # macOS app bundle metadata
├── Sources/
│   ├── App/
│   │   ├── GalaxyBudsManagerApp.swift     # @main, MenuBarExtra
│   │   └── AppState.swift                 # Coordinator, auto-reconnect
│   ├── Bluetooth/
│   │   └── BluetoothManager.swift         # CoreBluetooth + IOBluetooth RFCOMM
│   ├── Protocol/
│   │   ├── BudsMessage.swift              # Packet encode/decode
│   │   ├── BudsMessageId.swift            # 90+ message IDs
│   │   ├── BudsMessageTypes.swift         # Constants, header layout
│   │   ├── BudsCRC16.swift                # CRC16-CCITT
│   │   ├── BudsProtocol.swift             # Orchestrator, all handlers
│   │   ├── BudsError.swift                # Error types
│   │   ├── CommandQueue.swift             # Actor-based queue w/ retries
│   │   ├── Decoders/                      # 12 decoders (status, version, serial, debug...)
│   │   └── Encoders/                      # 25+ encoders (noise, EQ, touch, find, device...)
│   ├── Device/
│   │   ├── DeviceState.swift              # 30+ @Published properties
│   │   ├── BudsDeviceSpec.swift           # Capability matrix
│   │   └── DevicePersistence.swift        # UserDefaults persistence
│   ├── Debug/
│   │   ├── ProtocolLogger.swift           # Actor-based logging with export
│   │   └── DebugView.swift                # Log viewer
│   ├── UI/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarLabel.swift         # Compact icon + battery %
│   │   │   └── MenuBarPopover.swift       # Main popover UI
│   │   ├── Features/
│   │   │   ├── NoiseControlView.swift
│   │   │   ├── EqualizerView.swift
│   │   │   ├── TouchControlView.swift
│   │   │   ├── VoiceDetectView.swift
│   │   │   ├── FindMyEarbudsView.swift
│   │   │   ├── FitTestView.swift
│   │   │   ├── DeviceInfoView.swift
│   │   │   └── AdvancedDiagnosticsView.swift
│   │   └── SettingsView.swift
│   └── Utils/
│       └── DataExtensions.swift
├── Tests/
│   └── GalaxyBudsManagerTests.swift
├── Docs/
│   └── CAPABILITY_MATRIX.md
└── README.md
```

---

## Build Instructions

### Prerequisites

- **macOS 13.0** (Ventura) or later
- **Swift 5.9+** (ships with Xcode Command Line Tools)
- No Xcode IDE required — everything uses the `swift` CLI

If you don't have the Swift toolchain:

```bash
xcode-select --install
```

### Quick Build + Run (Development)

```bash
# Build .app bundle and launch it
./run.sh
```

> **⚠️ Important:** Do NOT use `swift run` — it produces a bare executable that can't open RFCOMM connections. IOBluetooth requires a proper `.app` bundle. Always use `./run.sh` or `./build_app.sh` + `open`.

### Release Build + DMG (Recommended)

The `build_app.sh` script does everything in one command:

```bash
./build_app.sh
```

This will:

1. **Build** a release-optimized binary (`swift build -c release`)
2. **Create** a macOS `.app` bundle with proper structure
3. **Generate** `AppIcon.icns` from `app-icon.png` (7 sizes, standard + retina)
4. **Copy** `menubar-icon.png` into the app bundle (loaded at runtime as template image)
5. **Write** `Info.plist` with Bluetooth permission strings
6. **Package** everything into a `.dmg` with drag-to-install

After the script finishes:

```
.build/
├── Galaxy Buds2 Pro Manager.app/    ← The app
└── GalaxyBuds2-Pro-Manager.dmg     ← Distribution disk image
```

### Install from DMG

```bash
# Mount the DMG
open .build/GalaxyBuds2-Pro-Manager.dmg

# Drag "Galaxy Buds2 Pro Manager" to Applications
# Eject the DMG
```

### Run Without Installing

```bash
open ".build/Galaxy Buds2 Pro Manager.app"
```

### Rebuild Clean

```bash
swift package clean
./build_app.sh
```

---

## First Launch Setup

1. **Pair your earbuds** — Go to **System Settings → Bluetooth** and pair your Galaxy Buds2 Pro normally. The app requires this system-level pairing to access the RFCOMM/SPP data channel.

2. **Grant Bluetooth permission** — On first launch, macOS will ask for Bluetooth access. Click **Allow**.

3. **Connect** — The app will automatically scan and connect to your paired earbuds. The menu bar icon changes from grey to active when connected.

4. **That's it** — All controls are available from the menu bar popover. Settings are accessible from the gear icon at the bottom.

---

## Protocol Details

### Wire Format

```
┌─────┬──────────┬───────┬─────────┬───────────┬─────┐
│ SOM │ Header   │ MsgID │ Payload │ CRC16-CCITT│ EOM │
│ 0xFD│ 2 bytes  │ 1 byte│ N bytes │ 2 bytes   │ 0xDD│
└─────┴──────────┴───────┴─────────┴───────────┴─────┘
```

- **Header**: 11-bit payload size + flags (response, fragment, encryption)
- **CRC16-CCITT**: Polynomial 0x1021, initial value 0xFFFF
- **MsgID**: Identifies the message type (90+ known IDs)

### Key Message IDs

| ID | Name | Direction | Purpose |
|----|------|-----------|---------|
| 0x05 | MANAGER_INFO | App → Buds | Handshake response |
| 0x60 | STATUS_UPDATED | Buds → App | Basic battery |
| 0x61 | EXTENDED_STATUS_UPDATED | Buds → App | Full device state |
| 0x62 | CONNECTION_UPDATED | Buds → App | Connection changes |
| 0x63 | SOFTWARE_VERSION | Both | Firmware version |
| 0x78 | NOISE_CONTROL | App → Buds | ANC mode switch |
| 0x84 | AMBIENT_VOLUME | App → Buds | Ambient level |
| 0x86 | EQUALIZER | App → Buds | EQ preset |
| 0x92 | TOUCHPAD | App → Buds | Touch actions |
| 0xA0 | FIND_MY_EARBUDS | App → Buds | Start/stop beep |
| 0x9D | FIT_TEST | App → Buds | Start seal test |
| 0x9E | FIT_TEST_RESULT | Buds → App | Test result |
| 0xD0 | VOICE Detect | Both | Conversation detect |

### Supported Features

| Feature | Status | Notes |
|---------|--------|-------|
| Battery (L/R/Case) | ✅ Working | Via extended status 0x61 |
| Wearing Detection | ✅ Working | Via extended status 0x61 |
| Noise Control | ✅ Working | ANC / Ambient / Off |
| Ambient Volume | ✅ Working | Levels 0–2 |
| Extra High Ambient | ✅ Working | Protocol 0x96 |
| Equalizer | ✅ Working | 6 presets |
| Touchpad Lock | ✅ Working | Protocol 0x90 |
| Touch Actions | ✅ Working | Per-earbud long-press |
| Find My Earbuds | ✅ Working | Start/stop + per-bud mute |
| Voice Detect | ✅ Working | Auto Ambient on speech |
| Sidetone | ✅ Working | During calls |
| In-Band Ringtone | ✅ Working | Protocol 0x8A |
| Game Mode | ✅ Working | Low latency |
| Spatial Audio | ⚠️ Toggle only | Head tracking requires Samsung phone |
| Fit Test | ✅ Working | Seal test per ear |
| Firmware Info | ✅ Working | Read-only |
| Serial Number | ✅ Working | Read-only |
| Factory Reset | ✅ Working | With confirmation dialog |
| Reboot | ✅ Working | With confirmation dialog |
| Rename | ⚠️ Partial | Device may revert to default name |
| FOTA (Firmware Update) | ❌ Not supported | Too risky; use Samsung Galaxy Wearable |
| 360 Audio / Head Tracking | ❌ Not supported | Samsung ecosystem only |
| Custom Ambient Curve | ❌ Not supported | Requires Samsung app |

---

## Limitations

| Limitation | Explanation |
|------------|-------------|
| **Requires system pairing** | Earbuds must be paired in System Settings → Bluetooth before the app can connect via RFCOMM |
| **No firmware updates** | The FOTA protocol is complex and undocumented. Use Samsung Galaxy Wearable for updates |
| **No 360 Audio** | Head tracking requires a Samsung Galaxy phone |
| **Rename may not persist** | Samsung earbuds sometimes revert to their default name |
| **Spatial Audio is toggle-only** | Head tracking data is not controllable from macOS |
| **Voice Focus is read-only** | Cannot be changed via the SPP protocol |
| **Bluetooth discovery is limited** | CoreBluetooth handles BLE scanning; RFCOMM requires pre-paired devices |
| **Menu bar icon is custom** | Uses `menubar-icon.png` from the app bundle; falls back to SF Symbols if missing |

---

## Development

### Run Tests

```bash
swift test
```

Tests cover: CRC16 encoding, message encode/decode, header parsing, all decoders, all encoders, device state management, capability matrix, and command queue behavior.

### Debug Logging

Enable protocol logging in Settings → Debug. Logs are saved to `~/Library/Application Support/GalaxyBudsManager/logs/` and can be exported as text from the Advanced tab.

### Architecture Principles

1. **Menu-bar first** — No dock icon, no main window. Everything accessible from the menu bar.
2. **Notification-driven** — Device pushes state; app doesn't poll (except firmware/serial at connect).
3. **Command queue** — All outbound commands go through a queue with timeout (5s) and retries (2x).
4. **Actor-based concurrency** — `CommandQueue` and `ProtocolLogger` are Swift actors for thread safety.
5. **No UI freezing** — All Bluetooth operations are async. UI never blocks.
6. **Graceful degradation** — Missing features are marked "unsupported", not faked.

---

## Protocol Sources

This project implements the Samsung Galaxy Buds SPP (Serial Port Profile) protocol, documented through reverse engineering and community research:

- **GalaxyBudsClient** by timschneeb — [github.com/timschneeb/GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient) (GPLv3 reference; this project is independently implemented)
- **Galaxy Buds Plus RFComm Protocol Notes** — [GitHub](https://github.com/timschneeb/GalaxyBudsClient/blob/master/Galaxy%20Buds%20Plus%20RFComm%20Protocol%20Notes.md)
- **Gadgetbridge Galaxy Buds Protocol** — [gadgetbridge.org](https://gadgetbridge.org/internals/specifics/galaxy-buds-protocol/)
- **Samsung Galaxy Buds2 Pro (SM-R510)** — Bluetooth 5.3, SPP UUID `00001101-0000-1000-8000-00805F9B34FB`

> This project is not affiliated with Samsung Electronics. The protocol implementation is independently written based on publicly available documentation.

---

## License

This project is not licensed under GPL. The protocol layer is an independent implementation inspired by (but not copied from) GPL-licensed reference projects.

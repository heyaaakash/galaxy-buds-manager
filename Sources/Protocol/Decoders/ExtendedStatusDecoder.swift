// ExtendedStatusDecoder.swift
// Decoder for EXTENDED_STATUS_UPDATED (0x61) — comprehensive device state.
//
// This is the most important message in the protocol. The device sends it
// automatically on connection, and the client must respond with MANAGER_INFO.

import Foundation

/// Decodes an EXTENDED_STATUS_UPDATED (0x61) message payload.
///
/// Payload layout (17+ bytes):
/// ```
/// [0]  Interface revision
/// [1]  Wear state Left
/// [2]  Wear state Right
/// [3]  Battery Left (0-100)
/// [4]  Battery Right (0-100)
/// [5]  Is coupled (0/1)
/// [6]  Main connection (0=R, 1=L)
/// [7]  Placement status byte
/// [8]  Battery Case (0-100)
/// [9]  Ambient sound enabled (0/1)
/// [10] Ambient voice focus (0/1)
/// [11] Adjust sound sync (0/1)
/// [12] Equalizer mode (0-5)
/// [13] Touchpad lock (0/1)
/// [14] Touch options (MSB: left, LSB: right)
/// [15] Device color (MSB: left, LSB: right)
/// [16] Side tone enable (0/1)
/// [17] Extra high ambient (optional, depends on revision)
/// ```
struct ExtendedStatusDecoder {

    let interfaceRevision: Int
    let wearingLeft: WearingState
    let wearingRight: WearingState
    let batteryLeft: Int
    let batteryRight: Int
    let isCoupled: Bool
    let mainConnection: MainConnection
    let placementByte: UInt8
    let batteryCase: Int
    let ambientEnabled: Bool
    let ambientVoiceFocus: Bool
    let adjustSoundSync: Bool
    let equalizerMode: EqualizerPreset
    let touchpadLocked: Bool
    let touchLeft: TouchAction
    let touchRight: TouchAction
    let colorLeft: DeviceColor
    let colorRight: DeviceColor
    let sidetoneEnabled: Bool
    let extraHighAmbient: Bool

    /// All raw payload bytes for logging.
    let rawPayload: [UInt8]

    init(payload: [UInt8]) throws {
        guard payload.count >= 17 else {
            throw BudsError.invalidPacket("Extended status payload too short: \(payload.count) bytes")
        }

        rawPayload = payload

        interfaceRevision = Int(payload[0])
        wearingLeft = WearingState(rawValue: Int(payload[1])) ?? .unknown
        wearingRight = WearingState(rawValue: Int(payload[2])) ?? .unknown
        batteryLeft = Int(payload[3])
        batteryRight = Int(payload[4])
        isCoupled = payload[5] != 0
        mainConnection = MainConnection(rawValue: Int(payload[6])) ?? .right
        placementByte = payload[7]
        batteryCase = Int(payload[8])
        ambientEnabled = payload[9] != 0
        ambientVoiceFocus = payload[10] != 0
        adjustSoundSync = payload[11] != 0
        equalizerMode = EqualizerPreset(rawValue: Int(payload[12])) ?? .disabled
        touchpadLocked = payload[13] != 0

        let touchByte = payload[14]
        touchLeft = TouchAction(rawValue: (touchByte >> 4) & 0x0F) ?? .none
        touchRight = TouchAction(rawValue: touchByte & 0x0F) ?? .none

        let colorByte = payload[15]
        colorLeft = DeviceColor(rawValue: (colorByte >> 4) & 0x0F) ?? .unknown
        colorRight = DeviceColor(rawValue: colorByte & 0x0F) ?? .unknown

        sidetoneEnabled = payload[16] != 0
        extraHighAmbient = payload.count > 17 ? payload[17] != 0 : false
    }

    /// Apply decoded values to device state.
    func apply(to state: DeviceState) {
        state.interfaceRevision = interfaceRevision
        state.wearingLeft = wearingLeft
        state.wearingRight = wearingRight
        state.batteryLeft = BatteryState(level: batteryLeft, isCharging: false, batteryType: nil)
        state.batteryRight = BatteryState(level: batteryRight, isCharging: false, batteryType: nil)
        state.isCoupled = isCoupled
        state.mainConnection = mainConnection
        state.placementByte = placementByte
        state.batteryCase = BatteryState(level: batteryCase, isCharging: false, batteryType: nil)
        state.ambientEnabled = ambientEnabled
        state.ambientVoiceFocus = ambientVoiceFocus
        state.adjustSoundSync = adjustSoundSync
        state.equalizerPreset = equalizerMode
        state.touchpadLocked = touchpadLocked
        state.touchLeftAction = touchLeft
        state.touchRightAction = touchRight
        state.colorLeft = colorLeft
        state.colorRight = colorRight
        state.sidetoneEnabled = sidetoneEnabled
        state.extraHighAmbient = extraHighAmbient

        // Derive noise control mode (0=Off, 1=ANC, 2=Ambient)
        let rawNoiseMode = Int(rawPayload[9])
        if let mode = NoiseControlMode(rawValue: rawNoiseMode) {
            state.noiseControlMode = mode
            state.ancEnabled = (mode == .anc)
            state.ambientEnabled = (mode == .ambient)
        } else if ambientEnabled {
            state.noiseControlMode = .ambient
            state.ancEnabled = false
            state.ambientEnabled = true
        } else {
            state.noiseControlMode = .off
            state.ancEnabled = false
            state.ambientEnabled = false
        }

        ProtocolLogger.log(.info, """
            Extended status decoded:
              Revision: \(interfaceRevision)
              Battery: L=\(batteryLeft)% R=\(batteryRight)% Case=\(batteryCase)%
              Wearing: L=\(wearingLeft) R=\(wearingRight)
              Noise: \(state.noiseControlMode.description)
              EQ: \(equalizerMode)
              Touch: L=\(touchLeft) R=\(touchRight)
              Color: L=\(colorLeft) R=\(colorRight)
            """)
    }

    /// Format as human-readable debug string.
    var debugDescription: String {
        """
        ExtendedStatus:
          Revision: \(interfaceRevision)
          Battery:  L=\(batteryLeft)%  R=\(batteryRight)%  Case=\(batteryCase)%
          Wearing:  L=\(wearingLeft)  R=\(wearingRight)
          Coupled:  \(isCoupled)
          Main:     \(mainConnection)
          Ambient:  \(ambientEnabled)
          VoiceFocus: \(ambientVoiceFocus)
          Sync:     \(adjustSoundSync)
          EQ:       \(equalizerMode)
          Locked:   \(touchpadLocked)
          Touch:    L=\(touchLeft)  R=\(touchRight)
          Color:    L=\(colorLeft)  R=\(colorRight)
          Sidetone: \(sidetoneEnabled)
          ExtraHighAmbient: \(extraHighAmbient)
        """
    }
}

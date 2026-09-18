import Foundation

/// SM-R510 status layout. Optional tails are revision-gated; truncated packets
/// must never replace a valid device snapshot with guessed defaults.
struct ExtendedStatusDecoder {
    let rawPayload: [UInt8]
    var interfaceRevision: Int { Int(rawPayload[0]) }
    var batteryLeft: Int { Int(rawPayload[2]) }
    var batteryRight: Int { Int(rawPayload[3]) }
    var isCoupled: Bool { rawPayload[4] == 1 }
    var mainConnection: MainConnection { MainConnection(rawValue: Int(rawPayload[5])) ?? .right }
    var placementByte: UInt8 { rawPayload[6] }
    var wearingLeft: WearingState { WearingState(rawValue: Int(placementByte >> 4)) ?? .unknown }
    var wearingRight: WearingState { WearingState(rawValue: Int(placementByte & 15)) ?? .unknown }
    var batteryCase: Int { Int(rawPayload[7]) }
    var adjustSoundSync: Bool { rawPayload[8] == 1 }
    var equalizerMode: EqualizerPreset { EqualizerPreset(rawValue: Int(rawPayload[9])) ?? .disabled }
    var touchpadLocked: Bool { rawPayload[10] & 0x80 == 0 }
    var touchLeft: TouchAction { TouchAction(rawValue: rawPayload[11] >> 4) ?? .none }
    var touchRight: TouchAction { TouchAction(rawValue: rawPayload[11] & 15) ?? .none }
    var noiseMode: NoiseControlMode { NoiseControlMode(rawValue: Int(rawPayload[12])) ?? .off }
    var ambientEnabled: Bool { noiseMode == .ambient }
    var sidetoneEnabled: Bool { rawPayload[33] == 1 }
    var extraHighAmbient: Bool { interfaceRevision >= 13 && rawPayload.count > 45 && rawPayload[45] == 1 }
    var colorLeft: DeviceColor { color(at: 14) }
    var colorRight: DeviceColor { color(at: 16) }

    init(payload: [UInt8]) throws {
        guard let revision = payload.first else { throw BudsError.payloadMalformed }
        let required = revision >= 13 ? 45 : revision >= 11 ? 44 : revision >= 8 ? 43 : revision >= 3 ? 42 : revision >= 1 ? 41 : 34
        guard payload.count >= required else { throw BudsError.invalidPacket("Truncated Buds2 Pro status (revision \(revision), \(payload.count)/\(required) bytes)") }
        rawPayload = payload
    }

    private func color(at index: Int) -> DeviceColor {
        switch Int(rawPayload[index]) | Int(rawPayload[index + 1]) << 8 {
        case 325, 326: return .graphite
        case 327: return .white
        case 328: return .boraPurple
        default: return .unknown
        }
    }

    func apply(to state: DeviceState) {
        let charging = interfaceRevision >= 11 ? rawPayload[43] : 0
        state.interfaceRevision = interfaceRevision
        state.batteryLeft = BatteryState(level: batteryLeft, isCharging: charging & 16 != 0, batteryType: nil)
        state.batteryRight = BatteryState(level: batteryRight, isCharging: charging & 4 != 0, batteryType: nil)
        state.batteryCase = BatteryState(level: batteryCase == 0 ? nil : batteryCase, isCharging: charging & 1 != 0, batteryType: nil)
        state.wearingLeft = wearingLeft
        state.wearingRight = wearingRight
        state.placementByte = placementByte
        state.isCoupled = isCoupled
        state.mainConnection = mainConnection
        state.adjustSoundSync = adjustSoundSync
        state.gameModeEnabled = adjustSoundSync
        state.equalizerPreset = equalizerMode
        state.touchpadLocked = touchpadLocked
        state.touchEnabledFlags = rawPayload[10] & 0x3F
        state.touchLeftAction = touchLeft
        state.touchRightAction = touchRight
        state.noiseControlMode = noiseMode
        state.ancEnabled = noiseMode == .anc
        state.ambientEnabled = ambientEnabled
        state.bixbyWakeupEnabled = rawPayload[13] == 1
        state.colorLeft = colorLeft
        state.colorRight = colorRight
        state.ambientVolume = Int(rawPayload[23])
        state.detectConversations = rawPayload[26] == 1
        state.detectConversationsDuration = Int(min(rawPayload[27], 2))
        state.ancWithOneEarbud = rawPayload[28] == 1
        state.sidetoneEnabled = sidetoneEnabled
        state.extraHighAmbient = extraHighAmbient
        state.spatialAudioEnabled = interfaceRevision >= 1 && rawPayload[35] == 1
        state.stereoBalance = min(Int(rawPayload[25]), 32)
        state.doubleTapVolume = rawPayload[32] == 1
        state.seamlessConnection = rawPayload[19] == 0
        state.customAmbientEnabled = rawPayload[29] == 1
        state.customAmbientLeft = Int(rawPayload[30] >> 4)
        state.customAmbientRight = Int(rawPayload[30] & 15)
        state.customAmbientTone = Int(rawPayload[31])
        state.extraClearCallSound = interfaceRevision >= 13 && rawPayload[44] == 1
        state.hasReceivedStatus = true
    }

    var debugDescription: String {
        "Buds2 Pro rev \(interfaceRevision): L=\(batteryLeft), R=\(batteryRight), case=\(batteryCase), noise=\(noiseMode), EQ=\(equalizerMode)"
    }
}

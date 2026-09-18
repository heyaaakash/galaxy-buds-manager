// ProtocolEncoders.swift
// All encoders for Samsung Galaxy Buds2 Pro protocol commands.

import Foundation

// MARK: - Manager Info Encoder

enum ManagerInfoEncoder {
    enum ClientType: UInt8 {
        case wearableApp = 1
        case other       = 2
    }

    static func encode(
        isSamsungDevice: Bool = false,
        sdkVersion: UInt8 = 0
    ) -> BudsMessage {
        let payload: [UInt8] = [
            1,
            isSamsungDevice ? 0x01 : 0x02,
            sdkVersion
        ]
        return BudsMessage.request(.managerInfo, payload: payload)
    }
}

// MARK: - Update Time Encoder

enum UpdateTimeEncoder {
    static func encode(date: Date = Date()) -> BudsMessage {
        let timezoneOffset = TimeInterval(TimeZone.current.secondsFromGMT()) * 1000.0
        let epoch = Int64(date.timeIntervalSince1970 * 1000)
        var payload = [UInt8](repeating: 0, count: 12)

        for i in 0..<8 {
            payload[i] = UInt8((epoch >> (i * 8)) & 0xFF)
        }

        let tzMs = Int32(timezoneOffset)
        for i in 0..<4 {
            payload[8 + i] = UInt8((tzMs >> (i * 8)) & 0xFF)
        }

        return BudsMessage.request(.updateTime, payload: payload)
    }
}

// MARK: - Equalizer Encoder

enum EqualizerEncoder {
    static func encode(preset: EqualizerPreset) -> BudsMessage {
        return BudsMessage.request(.equalizer, payload: [UInt8(preset.rawValue)])
    }
}

// MARK: - Noise Control Encoder

enum NoiseControlEncoder {
    static func encode(mode: NoiseControlMode) -> BudsMessage {
        return BudsMessage.request(.noiseControls, payload: [UInt8(mode.rawValue)])
    }
}

// MARK: - Ambient Mode Encoder

enum AmbientEncoder {
    static func setEnabled(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setAmbientMode, payload: [enabled ? 0x01 : 0x00])
    }

    static func setVolume(_ volume: Int, maximum: Int = 2) -> BudsMessage {
        let clamped = max(0, min(volume, maximum))
        return BudsMessage.request(.ambientVolume, payload: [UInt8(clamped)])
    }

    static func setExtraHigh(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.extraHighAmbient, payload: [enabled ? 0x01 : 0x00])
    }

    static func customizeAmbient(left: UInt8, center: UInt8, right: UInt8) -> BudsMessage {
        customize(enabled: true, left: Int(left), right: Int(right), tone: Int(center))
    }

    static func customize(enabled: Bool, left: Int, right: Int, tone: Int, maximum: Int = 2) -> BudsMessage {
        .request(.customizeAmbientSound, payload: [enabled ? 1 : 0,
            UInt8(max(0, min(left, maximum))), UInt8(max(0, min(right, maximum))), UInt8(max(0, min(tone, 4)))])
    }

    static func setNoiseReductionLevel(_ level: UInt8) -> BudsMessage {
        return BudsMessage.request(.noiseReductionLevel, payload: [level])
    }

    static func setAmplifyAmbient(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setAmplifyAmbientSound, payload: [enabled ? 0x01 : 0x00])
    }
}

// MARK: - Touchpad Encoder

enum TouchpadEncoder {
    static func lock(_ locked: Bool, flags: UInt8 = 0x3F, revision: Int = 1) -> BudsMessage {
        let bits: [UInt8] = revision >= 1 ? [3, 2, 1, 0, 4, 5] : [3, 2, 1, 0]
        return BudsMessage.request(.lockTouchpad, payload: [locked ? 0 : 1] + bits.map { (flags >> $0) & 1 })
    }

    static func setActions(left: TouchAction, right: TouchAction) -> BudsMessage {
        return BudsMessage.request(.setTouchpadOption, payload: [left.rawValue, right.rawValue])
    }

    static func setTouchAndHoldNoiseControls(left: UInt8, right: UInt8) -> BudsMessage {
        return BudsMessage.request(.setTouchAndHoldNoiseControls, payload: [left, right])
    }
}

// MARK: - Find My Earbuds Encoder

enum FindMyEarbudsEncoder {
    static func start() -> BudsMessage {
        return BudsMessage.request(.findMyEarbudsStart)
    }

    static func stop() -> BudsMessage {
        return BudsMessage.request(.findMyEarbudsStop)
    }

    static func startOnWearing() -> BudsMessage {
        return BudsMessage.request(.findMyEarbudsOnWearingStart)
    }

    static func mute(left: Bool, right: Bool) -> BudsMessage {
        return BudsMessage.request(.muteEarbud, payload: [
            left ? 0x01 : 0x00,
            right ? 0x01 : 0x00
        ])
    }
}

// MARK: - Spatial Audio Encoder

enum SpatialAudioEncoder {
    static func setEnabled(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setSpatialAudio, payload: [enabled ? 0x01 : 0x00])
    }
}

// MARK: - Game Mode Encoder

enum GameModeEncoder {
    static func setEnabled(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.gameMode, payload: [enabled ? 0x01 : 0x00])
    }
}

// MARK: - Voice & Call Encoders

enum VoiceCallEncoder {
    static func setDetectConversations(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setDetectConversations, payload: [enabled ? 0x01 : 0x00])
    }

    static func setDetectConversationsDuration(_ duration: UInt8) -> BudsMessage {
        return BudsMessage.request(.setDetectConversationsDuration, payload: [duration])
    }

    static func setSidetone(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setSidetone, payload: [enabled ? 0x01 : 0x00])
    }

    static func setInBandRingtone(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setInBandRingtone, payload: [enabled ? 0x01 : 0x00])
    }

    static func setVoiceNotification(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.voiceNotiStatus, payload: [enabled ? 0x01 : 0x00])
    }

    static func setAdaptiveVolume(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setAdaptiveVolumeEnabled, payload: [enabled ? 0x01 : 0x00])
    }

    static func setPauseMediaOnRemoval(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.pauseMediaWhenOneBudRemoved, payload: [enabled ? 0x01 : 0x00])
    }

    static func setCallPathControl(_ value: UInt8) -> BudsMessage {
        return BudsMessage.request(.setCallPathControl, payload: [value])
    }

    static func setExtraClearCallSound(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.extraClearSoundCall, payload: [enabled ? 0x01 : 0x00])
    }
}

// MARK: - ANC Encoder

enum AncEncoder {
    static func setAncWithOneEarbud(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setAncWithOneEarbud, payload: [enabled ? 0x01 : 0x00])
    }

    static func setAdjustSoundSync(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.adjustSoundSync, payload: [enabled ? 0x01 : 0x00])
    }
}

// MARK: - Adaptive EQ Encoder

enum AdaptiveEqEncoder {
    static func setEnabled(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.adaptiveEqControl, payload: [enabled ? 0x01 : 0x00])
    }
}

// MARK: - Device Management Encoders

enum DeviceManagementEncoder {
    static func reset() -> BudsMessage {
        return BudsMessage.request(.reset)
    }

    static func reboot() -> BudsMessage {
        return BudsMessage.request(.reboot)
    }

    static func poweroff() -> BudsMessage {
        return BudsMessage.request(.poweroff)
    }

    static func rename(name: String) -> BudsMessage {
        // Samsung uses a custom rename protocol; name is UTF-8 encoded
        var payload = Array(name.utf8)
        payload.append(0)  // null terminator
        return BudsMessage.request(.getPersonalName, payload: payload)
    }

    static func setSeamlessConnection(_ enabled: Bool) -> BudsMessage {
        return BudsMessage.request(.setSeamlessConnection, payload: [enabled ? 0x00 : 0x01])
    }
}

// MARK: - Fit Test Encoder

enum FitTestEncoder {
    static func startCheck() -> BudsMessage {
        return BudsMessage.request(.checkFitOfEarbuds, payload: [1])
    }
}

// MARK: - Debug Encoders

enum DebugEncoder {
    static func debugGetAllData() -> BudsMessage {
        return BudsMessage.request(.debugGetAllData)
    }

    static func debugSerialNumber() -> BudsMessage {
        return BudsMessage.request(.debugSerialNumber)
    }

    static func debugBuildInfo() -> BudsMessage {
        return BudsMessage.request(.debugBuildInfo)
    }

    static func debugGetVersion() -> BudsMessage {
        return BudsMessage.request(.debugGetVersion)
    }

    static func debugSku() -> BudsMessage {
        return BudsMessage.request(.debugSku)
    }

    static func cradleSerialNumber() -> BudsMessage {
        return BudsMessage.request(.cradleSerialNumber)
    }

    static func socBatteryCycle() -> BudsMessage {
        return BudsMessage.request(.socBatteryCycle)
    }

    static func batteryType() -> BudsMessage {
        return BudsMessage.request(.batteryType)
    }
}

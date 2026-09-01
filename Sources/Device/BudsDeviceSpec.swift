// BudsDeviceSpec.swift
// Device specification defining capabilities, protocol parameters, and supported features
// for the Samsung Galaxy Buds2 Pro (SM-R510).

import Foundation

// MARK: - Supported Features

/// Features that can be checked on the device spec.
enum BudsFeature: String, CaseIterable, Sendable {
    case seamlessConnection       = "SeamlessConnection"
    case stereoPan                = "StereoPan"
    case doubleTapVolume          = "DoubleTapVolume"
    case firmwareUpdates          = "FirmwareUpdates"
    case detectConversations      = "DetectConversations"
    case noiseControl             = "NoiseControl"
    case noiseControlDualSide     = "NoiseControlDualSide"
    case gamingMode               = "GamingMode"
    case caseBattery              = "CaseBattery"
    case fragmentedMessages       = "FragmentedMessages"
    case spatialSensor            = "SpatialSensor"
    case bixbyWakeup              = "BixbyWakeup"
    case gearFitTest              = "GearFitTest"
    case extraClearCallSound      = "ExtraClearCallSound"
    case ambientExtraLoud         = "AmbientExtraLoud"
    case ambientSound             = "AmbientSound"
    case anc                      = "ANC"
    case ambientSidetone          = "AmbientSidetone"
    case ambientCustomize         = "AmbientCustomize"
    case noiseControlsWithOneEarbud = "NoiseControlsWithOneEarbud"
    case debugSku                 = "DebugSku"
    case advancedTouchLock        = "AdvancedTouchLock"
    case advancedTouchLockForCalls = "AdvancedTouchLockForCalls"
    case fmgRingWhileWearing      = "FmgRingWhileWearing"
    case callPathControl          = "CallPathControl"
    case chargingState            = "ChargingState"
    case autoAdjustSound          = "AutoAdjustSound"
    case headTracking             = "HeadTracking"
    case cradleSerialNumber       = "CradleSerialNumber"
    case deviceColor              = "DeviceColor"
    case rename                   = "Rename"
    case smartThingsFind          = "SmartThingsFind"
    case usageReport              = "UsageReport"
    case ambientSoundVolume       = "AmbientSoundVolume"
    case ancNoiseReductionLevels  = "AncNoiseReductionLevels"
}

// MARK: - Feature Rule

/// Minimum firmware revision required for a feature (if applicable).
struct FeatureRule: Sendable {
    let minimumExtendedStatusRevision: Int
    let minimumStatusRevision: Int?

    init(_ revision: Int, _ statusRevision: Int? = nil) {
        self.minimumExtendedStatusRevision = revision
        self.minimumStatusRevision = statusRevision
    }
}

// MARK: - Device Model

/// Samsung Galaxy Buds model identifiers.
enum BudsModel: String, Sendable {
    case buds2Pro = "SM-R510"
    case budsPro  = "SM-R190"
    case buds2    = "SM-R177"
    case budsLive = "SM-R180"
    case budsPlus = "SM-R175"
    case buds     = "SM-R170"
    case budsFe   = "SM-R400"
    case buds3Pro = "SM-R630"
}

// MARK: - Device Specification

/// Complete specification for the Galaxy Buds2 Pro.
/// Defines which features are supported, protocol parameters, and device capabilities.
struct BudsDeviceSpec: Sendable {

    /// Device model.
    let model: BudsModel = .buds2Pro

    /// Human-readable device name.
    let deviceBaseName = "Galaxy Buds2 Pro"

    /// Samsung model number.
    let modelNumber = "SM-R510"

    /// SPP service UUID for connection.
    let serviceUuid: String = BudsConstants.sppNewUuid

    /// SOM/EOM bytes for this model.
    let startOfMessage: UInt8 = BudsConstants.som
    let endOfMessage: UInt8 = BudsConstants.eom

    /// Maximum ambient sound volume level (Buds2 Pro is limited to 2).
    let maximumAmbientVolume = 2

    /// Features supported by this model, with optional revision requirements.
    let supportedFeatures: [BudsFeature: FeatureRule?] = [
        .seamlessConnection: nil,
        .stereoPan: nil,
        .doubleTapVolume: nil,
        .firmwareUpdates: nil,
        .detectConversations: nil,
        .noiseControl: nil,
        .noiseControlDualSide: nil,
        .gamingMode: nil,
        .caseBattery: nil,
        .fragmentedMessages: nil,
        .spatialSensor: nil,
        .bixbyWakeup: nil,
        .gearFitTest: nil,
        .extraClearCallSound: FeatureRule(13),
        .ambientExtraLoud: FeatureRule(13),
        .ambientSound: nil,
        .anc: nil,
        .ambientSidetone: FeatureRule(1),
        .ambientCustomize: nil,
        .noiseControlsWithOneEarbud: nil,
        .debugSku: nil,
        .advancedTouchLock: nil,
        .advancedTouchLockForCalls: FeatureRule(1),
        .fmgRingWhileWearing: FeatureRule(4),
        .callPathControl: FeatureRule(1),
        .chargingState: FeatureRule(11),
        .autoAdjustSound: FeatureRule(3),
        .headTracking: FeatureRule(8),
        .cradleSerialNumber: nil,
        .deviceColor: nil,
        .rename: nil,
        .smartThingsFind: nil,
        .usageReport: nil,
        .ambientSoundVolume: nil,
        .ancNoiseReductionLevels: nil,
    ]

    /// Predefined equalizer presets for this model.
    let equalizerPresets: [EqualizerPreset] = [
        .disabled, .bassBoost, .soft, .dynamic, .clear, .trebleBoost
    ]

    /// Touchpad action options for this model.
    let touchpadActions: [TouchAction] = [
        .none, .voiceAssistant, .volume, .ambientSound, .noiseControl
    ]

    // MARK: - Queries

    /// Check if a feature is supported (without revision check).
    func supports(_ feature: BudsFeature) -> Bool {
        return supportedFeatures[feature] != nil
    }

    /// Check if a feature is supported given a specific firmware revision.
    func supports(_ feature: BudsFeature, firmwareRevision: Int?) -> Bool {
        guard let rule = supportedFeatures[feature] else { return false }
        guard let rule = rule else { return true }  // no restriction
        guard let revision = firmwareRevision else { return true }  // can't check, assume yes
        return revision >= rule.minimumExtendedStatusRevision
    }

    /// List all supported features.
    var allSupportedFeatures: [BudsFeature] {
        return supportedFeatures.keys.sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Capability Matrix

/// Documents the protocol capability matrix for Buds2 Pro.
/// What can be read, written, requires special characteristics, or is uncertain.
enum CapabilityMatrix {

    /// Commands that can be sent to the device.
    enum Access: String, Sendable {
        case read       = "Read"       // Can request and receive data
        case write      = "Write"      // Can send configuration commands
        case readWrite  = "Read+Write" // Both directions
        case unsupported = "N/A"       // Not supported on this model
        case uncertain  = "Unknown"    // Needs empirical testing
    }

    struct Capability: Sendable {
        let messageId: BudsMessageId
        let description: String
        let access: Access
        let requiresSpecialCharacteristic: Bool
        let notes: String
    }

    /// Full capability matrix for Buds2 Pro.
    static let matrix: [Capability] = [
        // Status & Connection
        Capability(messageId: .statusUpdated,
                   description: "Basic status (battery, placement)",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: "Automatically sent by device on connect"),
        Capability(messageId: .extendedStatusUpdated,
                   description: "Extended status (battery, ANC, EQ, touch, color)",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: "Automatically sent by device on connect; must respond with managerInfo"),
        Capability(messageId: .connectionUpdated,
                   description: "Connection topology change",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: "Sent when L/R role changes"),
        Capability(messageId: .versionInfo,
                   description: "Firmware version (short)",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .versionInfoLong,
                   description: "Firmware version (long)",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Manager
        Capability(messageId: .managerInfo,
                   description: "Manager app info (handshake)",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "Must send after receiving extendedStatusUpdated"),
        Capability(messageId: .updateTime,
                   description: "Sync device time",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "8-byte timestamp + 4-byte timezone"),

        // Noise Control
        Capability(messageId: .noiseControls,
                   description: "Set noise control mode",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "0=Off, 1=ANC, 2=Ambient"),
        Capability(messageId: .noiseControlsUpdate,
                   description: "Noise control state changed",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: "Sent by device when mode changes"),
        Capability(messageId: .setAncWithOneEarbud,
                   description: "ANC with one earbud",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Ambient Sound
        Capability(messageId: .setAmbientMode,
                   description: "Enable/disable ambient sound",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .ambientVolume,
                   description: "Set ambient volume",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "0-2 (max 2 for Buds2 Pro)"),
        Capability(messageId: .customizeAmbientSound,
                   description: "Customize ambient sound levels",
                   access: .readWrite, requiresSpecialCharacteristic: false,
                   notes: "3-band adjustment"),
        Capability(messageId: .noiseReductionLevel,
                   description: "Noise reduction level",
                   access: .readWrite, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .extraHighAmbient,
                   description: "Extra-high ambient volume",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "Requires firmware revision >= 13"),

        // Equalizer
        Capability(messageId: .equalizer,
                   description: "Set equalizer preset",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "0-5"),
        Capability(messageId: .customEqualizeSend,
                   description: "Send custom EQ curve",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .customEqualizeRecv,
                   description: "Receive custom EQ curve",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Touch
        Capability(messageId: .lockTouchpad,
                   description: "Lock/unlock touchpad",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .setTouchpadOption,
                   description: "Set touchpad long-press actions",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "Left and right independently"),
        Capability(messageId: .touchUpdated,
                   description: "Touch settings update notification",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Find My Earbuds
        Capability(messageId: .findMyEarbudsStart,
                   description: "Start find-my-earbuds",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "Plays loud beeping"),
        Capability(messageId: .findMyEarbudsStop,
                   description: "Stop find-my-earbuds",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .muteEarbud,
                   description: "Mute earbud in find mode",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Spatial Audio
        Capability(messageId: .setSpatialAudio,
                   description: "Set spatial audio on/off",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .spatialAudioData,
                   description: "Spatial audio head tracking data",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Battery
        Capability(messageId: .batteryType,
                   description: "Battery type information",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Voice & Call
        Capability(messageId: .setDetectConversations,
                   description: "Detect conversations setting",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .setSidetone,
                   description: "Sidetone during calls",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .setInBandRingtone,
                   description: "In-band ringtone",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Game Mode
        Capability(messageId: .gameMode,
                   description: "Game/low-latency mode",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Adaptive
        Capability(messageId: .setAdaptiveVolumeEnabled,
                   description: "Adaptive volume",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .adaptiveEqControl,
                   description: "Adaptive EQ",
                   access: .readWrite, requiresSpecialCharacteristic: false,
                   notes: ""),

        // Debug
        Capability(messageId: .debugGetAllData,
                   description: "Debug: get all data",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: "Returns sensor measurements"),
        Capability(messageId: .debugSerialNumber,
                   description: "Debug: serial number",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .debugBuildInfo,
                   description: "Debug: build info",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .debugSku,
                   description: "Debug: SKU",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: ""),

        // System
        Capability(messageId: .reset,
                   description: "Factory reset",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: "Destructive!"),
        Capability(messageId: .reboot,
                   description: "Reboot device",
                   access: .write, requiresSpecialCharacteristic: false,
                   notes: ""),
        Capability(messageId: .selfTest,
                   description: "Run self-test",
                   access: .read, requiresSpecialCharacteristic: false,
                   notes: "Disconnects buds during test"),

        // FOTA
        Capability(messageId: .fotaSession,
                   description: "FOTA session",
                   access: .uncertain, requiresSpecialCharacteristic: false,
                   notes: "Firmware update - complex protocol, needs empirical testing"),
        Capability(messageId: .fotaControl,
                   description: "FOTA control",
                   access: .uncertain, requiresSpecialCharacteristic: false,
                   notes: ""),
    ]

    /// Get capabilities filtered by access type.
    static func capabilities(withAccess access: Access) -> [Capability] {
        return matrix.filter { $0.access == access }
    }

    /// Get all readable capabilities.
    static var readable: [Capability] { capabilities(withAccess: .read) }

    /// Get all writable capabilities.
    static var writable: [Capability] { capabilities(withAccess: .write) }

    /// Get uncertain capabilities that need testing.
    static var uncertain: [Capability] { capabilities(withAccess: .uncertain) }

    /// Summary string for display.
    static func summary() -> String {
        let readable = capabilities(withAccess: .read).count
        let writable = capabilities(withAccess: .write).count
        let readWrite = capabilities(withAccess: .readWrite).count
        let uncertain = capabilities(withAccess: .uncertain).count
        let unsupported = capabilities(withAccess: .unsupported).count
        return """
        Buds2 Pro Capability Matrix:
          Readable:      \(readable)
          Writable:      \(writable)
          Read+Write:    \(readWrite)
          Uncertain:     \(uncertain)
          Unsupported:   \(unsupported)
          Total known:   \(matrix.count)
        """
    }
}

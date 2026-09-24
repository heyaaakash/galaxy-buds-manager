// DeviceState.swift
// Complete device state model for Samsung Galaxy Buds2 Pro.
// Tracks battery, ANC, ambient, equalizer, touch, voice, find, diagnostics, and firmware state.

import Foundation
import Combine

// MARK: - Battery State

/// Battery information for a single bud or the charging case.
struct BatteryState: Equatable, Sendable {
    let level: Int?
    let isCharging: Bool
    let batteryType: String?

    init(level: Int?, isCharging: Bool, batteryType: String?) {
        self.level = level.flatMap { (0...100).contains($0) ? $0 : nil }
        self.isCharging = isCharging
        self.batteryType = batteryType
    }

    static let unknown = BatteryState(level: nil, isCharging: false, batteryType: nil)

    var levelString: String {
        level.map { "\($0)%" } ?? "--"
    }
}

// MARK: - Wearing State

enum WearingState: Int, CustomStringConvertible, Sendable, CaseIterable {
    case unknown     = 0
    case wearing     = 1
    case notWearing  = 2
    case inCase      = 3
    case inClosedCase = 4

    var description: String {
        switch self {
        case .unknown:      return "Unknown"
        case .wearing:      return "In Ear"
        case .notWearing:   return "Not Worn"
        case .inCase:       return "In Case (Open)"
        case .inClosedCase: return "In Case (Closed)"
        }
    }

    var icon: String {
        switch self {
        case .wearing:      return "earbuds"
        case .notWearing:   return "earbuds"
        case .inCase, .inClosedCase: return "batterycaseportrait"
        case .unknown:      return "questionmark.circle"
        }
    }
}

// MARK: - Noise Control Mode

enum NoiseControlMode: Int, CustomStringConvertible, Sendable {
    case off      = 0
    case anc      = 1
    case ambient  = 2

    var description: String {
        switch self {
        case .off:     return "Off"
        case .anc:     return "ANC"
        case .ambient: return "Ambient"
        }
    }

    var fullDescription: String {
        switch self {
        case .off:     return "Noise Cancellation Off"
        case .anc:     return "Active Noise Cancellation"
        case .ambient: return "Ambient Sound"
        }
    }

    var icon: String {
        switch self {
        case .anc:     return "waveform.path.badge.minus"
        case .ambient: return "waveform.path"
        case .off:     return "speaker.slash"
        }
    }
}

// MARK: - Equalizer Preset

enum EqualizerPreset: Int, CustomStringConvertible, Sendable, CaseIterable {
    case disabled   = 0
    case bassBoost  = 1
    case soft       = 2
    case dynamic    = 3
    case clear      = 4
    case trebleBoost = 5

    var description: String {
        switch self {
        case .disabled:    return "Normal"
        case .bassBoost:   return "Bass Boost"
        case .soft:        return "Soft"
        case .dynamic:     return "Dynamic"
        case .clear:       return "Clear"
        case .trebleBoost: return "Treble Boost"
        }
    }
}

// MARK: - Touch Action

enum TouchAction: UInt8, CustomStringConvertible, Sendable, CaseIterable {
    case none            = 0
    case voiceAssistant  = 1
    case volume          = 3
    case ambientSound    = 6
    case spotifySpotOn   = 4
    case noiseControl    = 2

    var description: String {
        switch self {
        case .none:           return "None"
        case .voiceAssistant: return "Voice Assistant"
        case .volume:         return "Volume"
        case .ambientSound:   return "Ambient Sound"
        case .spotifySpotOn:  return "Spotify"
        case .noiseControl:   return "Noise Control"
        }
    }
}

// MARK: - Device Color

enum DeviceColor: UInt8, CustomStringConvertible, Sendable {
    case graphite     = 0
    case white        = 1
    case boraPurple   = 2
    case fakeBlack    = 3
    case paleBlue     = 4
    case olive        = 5
    case unknown      = 0xFF

    var description: String {
        switch self {
        case .graphite:   return "Graphite"
        case .white:      return "White"
        case .boraPurple: return "Bora Purple"
        case .fakeBlack:  return "Black"
        case .paleBlue:   return "Pale Blue"
        case .olive:      return "Olive"
        case .unknown:    return "Unknown"
        }
    }
}

// MARK: - Connection State

enum ConnectionState: CustomStringConvertible, Sendable, Equatable {
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.scanning, .scanning): return true
        case (.connecting, .connecting): return true
        case (.reconnecting(let a), .reconnecting(let b)): return a == b
        case (.connected, .connected): return true
        case (.disconnecting, .disconnecting): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
    case disconnected
    case scanning
    case connecting
    case reconnecting(attempt: Int)
    case connected
    case disconnecting
    case error(String)

    var description: String {
        switch self {
        case .disconnected:            return "Galaxy Buds unavailable"
        case .scanning:                return "Scanning for Galaxy Buds..."
        case .connecting:              return "Connecting…"
        case .reconnecting(let n):      return "Reconnecting… (attempt \(n))"
        case .connected:               return "● Galaxy Buds"
        case .disconnecting:           return "Disconnecting…"
        case .error(let msg):          return "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isConnectingOrReconnecting: Bool {
        switch self {
        case .connecting, .reconnecting: return true
        default: return false
        }
    }

    var errorDescription: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Main Connection Role

enum MainConnection: Int, CustomStringConvertible, Sendable {
    case right = 0
    case left  = 1

    var description: String {
        switch self {
        case .right: return "Right"
        case .left:  return "Left"
        }
    }
}

// MARK: - Device State

/// Complete observable state of a Galaxy Buds2 Pro device.
final class DeviceState: ObservableObject, @unchecked Sendable {

    // MARK: - Connection
    @Published var connectionState: ConnectionState = .disconnected
    @Published var deviceAddress = ""
    @Published var deviceName: String = "Galaxy Buds2 Pro"

    // MARK: - Battery
    @Published var batteryLeft: BatteryState = .unknown
    @Published var batteryRight: BatteryState = .unknown
    @Published var batteryCase: BatteryState = .unknown

    // MARK: - Placement
    @Published var wearingLeft: WearingState = .unknown
    @Published var wearingRight: WearingState = .unknown

    // MARK: - Connection Details
    @Published var mainConnection: MainConnection = .right
    @Published var isCoupled: Bool = false
    @Published var placementByte: UInt8 = 0

    // MARK: - Noise Control
    @Published var noiseControlMode: NoiseControlMode = .off
    @Published var ancEnabled: Bool = false
    @Published var ambientEnabled: Bool = false
    @Published var ambientVolume: Int = 0
    @Published var extraHighAmbient: Bool = false
    @Published var ambientVoiceFocus: Bool = false
    @Published var adjustSoundSync: Bool = false
    @Published var ancWithOneEarbud: Bool = false

    // MARK: - Equalizer
    @Published var equalizerPreset: EqualizerPreset = .disabled
    @Published var customEqualizerBands: [Int] = []

    @Published var stereoBalance = 16
    @Published var doubleTapVolume = false
    @Published var seamlessConnection = false
    @Published var extraClearCallSound = false
    @Published var customAmbientEnabled = false
    @Published var customAmbientLeft = 1
    @Published var customAmbientRight = 1
    @Published var customAmbientTone = 2
    @Published var pendingCommands: Set<UInt8> = []
    @Published var hasReceivedStatus = false
    @Published var touchEnabledFlags: UInt8 = 0x3F
    @Published var fitTestRunning = false

    // MARK: - Touch
    @Published var touchpadLocked: Bool = false
    @Published var touchLeftAction: TouchAction = .none
    @Published var touchRightAction: TouchAction = .none

    // MARK: - Voice & Call
    @Published var bixbyWakeupEnabled: Bool = false
    @Published var detectConversations: Bool = false
    @Published var detectConversationsDuration: Int = 0
    @Published var sidetoneEnabled: Bool = false
    @Published var inBandRingtone: Bool = false
    @Published var voiceNotificationEnabled: Bool = false
    @Published var pauseMediaOnRemoval: Bool = false

    // MARK: - Audio Features
    @Published var spatialAudioEnabled: Bool = false
    @Published var gameModeEnabled: Bool = false
    @Published var adaptiveVolumeEnabled: Bool = false

    // MARK: - Firmware & Info
    @Published var firmwareVersion: String = ""
    @Published var firmwareVersionLong: String = ""
    @Published var serialNumber: String = ""
    @Published var cradleSerialNumber: String = ""
    @Published var colorLeft: DeviceColor = .unknown
    @Published var colorRight: DeviceColor = .unknown
    @Published var interfaceRevision: Int = 0
    @Published var buildInfo: String = ""
    @Published var sku: String = ""

    // MARK: - Diagnostics
    @Published var debugDataRaw: [UInt8] = []
    @Published var leftTemperature: Int? = nil
    @Published var rightTemperature: Int? = nil
    @Published var leftVoltage: Int? = nil
    @Published var rightVoltage: Int? = nil
    @Published var caseVoltage: Int? = nil
    @Published var leftCurrent: Int? = nil
    @Published var rightCurrent: Int? = nil
    @Published var batteryCycles: Int? = nil

    // MARK: - Find My Earbuds
    @Published var findMyActive: Bool = false
    @Published var findMyLeftMuted: Bool = false
    @Published var findMyRightMuted: Bool = false

    // MARK: - Fit Test
    @Published var fitTestResult: FitTestResult? = nil

    // MARK: - Derived Properties

    var isNoiseControlActive: Bool { noiseControlMode != .off }

    var averageBattery: Int? {
        let levels = [batteryLeft.level, batteryRight.level].compactMap { $0 }
        guard !levels.isEmpty else { return nil }
        return levels.reduce(0, +) / levels.count
    }

    var allInCase: Bool {
        (wearingLeft == .inCase || wearingLeft == .inClosedCase) &&
        (wearingRight == .inCase || wearingRight == .inClosedCase)
    }

    var isAnyBudWorn: Bool {
        wearingLeft == .wearing || wearingRight == .wearing
    }

    var connectionSummary: String {
        "\(mainConnection.description) connected, \(isCoupled ? "coupled" : "single")"
    }

    /// Reset all state to defaults.
    func reset() {
        connectionState = .disconnected
        batteryLeft = .unknown
        batteryRight = .unknown
        batteryCase = .unknown
        wearingLeft = .unknown
        wearingRight = .unknown
        mainConnection = .right
        isCoupled = false
        placementByte = 0
        noiseControlMode = .off
        ancEnabled = false
        ambientEnabled = false
        ambientVolume = 0
        extraHighAmbient = false
        ambientVoiceFocus = false
        adjustSoundSync = false
        ancWithOneEarbud = false
        equalizerPreset = .disabled
        customEqualizerBands = []
        stereoBalance = 16
        doubleTapVolume = false
        seamlessConnection = false
        extraClearCallSound = false
        customAmbientEnabled = false
        customAmbientLeft = 1
        customAmbientRight = 1
        customAmbientTone = 2
        pendingCommands = []
        hasReceivedStatus = false
        touchEnabledFlags = 0x3F
        fitTestRunning = false
        touchpadLocked = false
        touchLeftAction = .none
        touchRightAction = .none
        bixbyWakeupEnabled = false
        detectConversations = false
        detectConversationsDuration = 0
        sidetoneEnabled = false
        inBandRingtone = false
        voiceNotificationEnabled = false
        pauseMediaOnRemoval = false
        spatialAudioEnabled = false
        gameModeEnabled = false
        adaptiveVolumeEnabled = false
        firmwareVersion = ""
        firmwareVersionLong = ""
        serialNumber = ""
        cradleSerialNumber = ""
        colorLeft = .unknown
        colorRight = .unknown
        interfaceRevision = 0
        buildInfo = ""
        sku = ""
        debugDataRaw = []
        leftTemperature = nil
        rightTemperature = nil
        leftVoltage = nil
        rightVoltage = nil
        caseVoltage = nil
        leftCurrent = nil
        rightCurrent = nil
        batteryCycles = nil
        findMyActive = false
        findMyLeftMuted = false
        findMyRightMuted = false
        fitTestResult = nil
    }
}

// MARK: - Fit Test Result

/// Result of a fit/seal test.
enum FitTestResult: Sendable {
    case passed
    case failedLeft
    case failedRight
    case failedBoth
    case unknown

    var description: String {
        switch self {
        case .passed:      return "Good Fit"
        case .failedLeft:  return "Left earbud: poor seal"
        case .failedRight: return "Right earbud: poor seal"
        case .failedBoth:  return "Both earbuds: poor seal"
        case .unknown:     return "Unknown"
        }
    }
}

// ConnectionUpdateDecoder.swift
// All decoders for Galaxy Buds2 Pro SPP responses.

import Foundation

// MARK: - Connection Update Decoder

struct ConnectionUpdateDecoder {
    let mainConnection: MainConnection
    let isCoupled: Bool

    init(payload: [UInt8]) throws {
        guard payload.count >= 1 else { throw BudsError.payloadMalformed }
        mainConnection = MainConnection(rawValue: Int(payload[0])) ?? .right
        isCoupled = payload.count > 1 ? payload[1] != 0 : false
    }

    func apply(to state: DeviceState) {
        state.mainConnection = mainConnection
        state.isCoupled = isCoupled
    }
}

// MARK: - Version Info Decoder

struct VersionInfoDecoder {
    let firmwareVersion: String
    let rawPayload: [UInt8]

    init(payload: [UInt8]) throws {
        rawPayload = payload
        if payload.count == 10 {
            let year = Int(payload[3] >> 4)
            let month = Int(payload[3] & 15)
            let release = Int(payload[4])
            let years = Array("OPQRSTUVWXYZ")
            let months = Array("ABCDEFGHIJKL")
            let releases = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            guard year < years.count, month < months.count, release < releases.count else { throw BudsError.payloadMalformed }
            firmwareVersion = "R510XX" + (payload[2] == 0 ? "E" : "U") + "0A" + String(years[year]) + String(months[month]) + String(releases[release])
        } else if let str = String(data: Data(payload), encoding: .utf8), payload.allSatisfy({ $0 == 0 || (32...126).contains($0) }) {
            firmwareVersion = str.trimmingCharacters(in: .controlCharacters)
        } else {
            throw BudsError.payloadMalformed
        }
    }

    func apply(to state: DeviceState, isLong: Bool = false) {
        if isLong {
            state.firmwareVersionLong = firmwareVersion
            if state.firmwareVersion.isEmpty {
                state.firmwareVersion = firmwareVersion
            }
        } else {
            state.firmwareVersion = firmwareVersion
        }
    }
}

// MARK: - Noise Controls Update Decoder

struct NoiseControlsUpdateDecoder {
    let mode: NoiseControlMode
    let volume: Int = 0 // Noise notifications do not carry ambient volume.

    init(payload: [UInt8]) throws {
        guard !payload.isEmpty else { throw BudsError.payloadMalformed }
        mode = NoiseControlMode(rawValue: Int(payload[0])) ?? .off
    }

    func apply(to state: DeviceState) {
        state.noiseControlMode = mode
        state.ancEnabled = (mode == .anc)
        state.ambientEnabled = (mode == .ambient)
    }
}

// MARK: - Touch Updated Decoder

struct TouchUpdatedDecoder {
    let touchpadLocked: Bool
    init(payload: [UInt8]) throws {
        guard let value = payload.first else { throw BudsError.payloadMalformed }
        touchpadLocked = value == 1
    }
    func apply(to state: DeviceState) { state.touchpadLocked = touchpadLocked }
}

// MARK: - Ambient Mode Updated Decoder

struct AmbientModeUpdatedDecoder {
    let enabled: Bool
    let volume: Int

    init(payload: [UInt8]) throws {
        guard !payload.isEmpty else { throw BudsError.payloadMalformed }
        enabled = payload[0] != 0
        volume = payload.count > 1 ? Int(payload[1]) : 0
    }

    func apply(to state: DeviceState) {
        state.ambientEnabled = enabled
        state.ambientVolume = volume
        if enabled {
            state.noiseControlMode = .ambient
        } else if !state.ancEnabled {
            state.noiseControlMode = .off
        }
    }
}

// MARK: - Mute Earbud Status Decoder

struct MuteEarbudStatusDecoder {
    let leftMuted: Bool
    let rightMuted: Bool

    init(payload: [UInt8]) throws {
        guard payload.count >= 2 else { throw BudsError.payloadMalformed }
        leftMuted = payload[0] != 0
        rightMuted = payload[1] != 0
    }

    func apply(to state: DeviceState) {
        state.findMyLeftMuted = leftMuted
        state.findMyRightMuted = rightMuted
    }
}

// MARK: - Debug All Data Decoder

/// Decodes DEBUG_GET_ALL_DATA (0x26) response.
/// This is a large payload with sensor data, voltages, temperatures, etc.
struct DebugAllDataDecoder {
    let rawPayload: [UInt8]

    init(payload: [UInt8]) {
        rawPayload = payload
    }

    func apply(to state: DeviceState) {
        state.debugDataRaw = rawPayload
        // The exact layout varies by firmware; attempt to extract known fields.
        // Voltage and temperature are typically at fixed offsets in the debug payload.
        // Without a fully reverse-engineered layout, we store raw bytes and display hex.
        ProtocolLogger.log(.info, "Debug data received: \(rawPayload.count) bytes")
    }
}

// MARK: - Serial Number Decoder

/// Decodes DEBUG_SERIAL_NUMBER (0x29) response.
struct SerialNumberDecoder {
    let serialLeft: String
    let serialRight: String
    let rawPayload: [UInt8]

    init(payload: [UInt8]) throws {
        rawPayload = payload
        guard payload.count >= 22 else { throw BudsError.payloadMalformed }
        serialLeft = String(decoding: payload.prefix(11), as: UTF8.self).trimmingCharacters(in: .controlCharacters)
        serialRight = String(decoding: payload.dropFirst(11).prefix(11), as: UTF8.self).trimmingCharacters(in: .controlCharacters)
    }

    func apply(to state: DeviceState) {
        if !serialLeft.isEmpty {
            state.serialNumber = serialLeft
        }
        if !serialRight.isEmpty && state.serialNumber.isEmpty {
            state.serialNumber = serialRight
        }
    }
}

// MARK: - Cradle Serial Number Decoder

/// Decodes CRADLE_SERIAL_NUMBER (0xCD) response.
struct CradleSerialNumberDecoder {
    let serialNumber: String
    init(payload: [UInt8]) throws {
        guard payload.count >= 20 else { throw BudsError.payloadMalformed }
        serialNumber = String(decoding: payload[9..<20], as: UTF8.self).trimmingCharacters(in: .controlCharacters)
    }
    func apply(to state: DeviceState) { state.cradleSerialNumber = serialNumber }
}

// MARK: - Build Info Decoder

/// Decodes DEBUG_BUILD_INFO (0x28) response.
struct BuildInfoDecoder {
    let buildInfo: String
    let rawPayload: [UInt8]

    init(payload: [UInt8]) throws {
        rawPayload = payload
        if let str = String(data: Data(payload), encoding: .utf8) {
            buildInfo = str.trimmingCharacters(in: .controlCharacters)
        } else {
            buildInfo = payload.map { String(format: "%02X", $0) }.joined()
        }
    }

    func apply(to state: DeviceState) {
        state.buildInfo = buildInfo
    }
}

// MARK: - SKU Decoder

/// Decodes DEBUG_SKU (0x22) response.
struct SkuDecoder {
    let sku: String

    init(payload: [UInt8]) throws {
        if let str = String(data: Data(payload), encoding: .utf8) {
            sku = str.trimmingCharacters(in: .controlCharacters)
        } else {
            sku = payload.map { String(format: "%02X", $0) }.joined()
        }
    }

    func apply(to state: DeviceState) {
        state.sku = sku
    }
}

// MARK: - Fit Test Result Decoder

/// Decodes CHECK_FIT_RESULT (0x9E) response.
struct FitTestResultDecoder {
    let result: FitTestResult

    init(payload: [UInt8]) throws {
        guard payload.count >= 2 else { throw BudsError.payloadMalformed }
        guard payload[0] <= 1, payload[1] <= 1 else { result = .unknown; return }
        let leftOk = payload[0] == 1
        let rightOk = payload[1] == 1

        switch (leftOk, rightOk) {
        case (true, true):   result = .passed
        case (false, true):  result = .failedLeft
        case (true, false):  result = .failedRight
        case (false, false): result = .failedBoth
        }
    }

    func apply(to state: DeviceState) {
        state.fitTestRunning = false
        state.fitTestResult = result
    }
}

// MARK: - Debug Version Decoder

/// Decodes DEBUG_GET_VERSION (0x24) response.
struct DebugVersionDecoder {
    let version: String

    init(payload: [UInt8]) throws {
        if let str = String(data: Data(payload), encoding: .utf8) {
            version = str.trimmingCharacters(in: .controlCharacters)
        } else {
            version = payload.map { String(format: "%02X", $0) }.joined()
        }
    }
}

// MARK: - SOC Battery Cycle Decoder

/// Decodes SOC_BATTERY_CYCLE (0xCE) response.
struct BatteryCycleDecoder {
    let leftCycles: UInt64
    let rightCycles: UInt64
    var cycleCount: Int { Int(max(leftCycles, rightCycles)) }
    init(payload: [UInt8]) throws {
        guard payload.count == 16 else { throw BudsError.payloadMalformed }
        func cycles(_ bytes: ArraySlice<UInt8>) -> UInt64 {
            bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } / 10000
        }
        leftCycles = cycles(payload[0..<8])
        rightCycles = cycles(payload[8..<16])
    }
    func apply(to state: DeviceState) { state.batteryCycles = cycleCount }
}

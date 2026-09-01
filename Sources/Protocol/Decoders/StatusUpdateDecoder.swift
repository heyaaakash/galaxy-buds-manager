// StatusUpdateDecoder.swift
// Decoder for STATUS_UPDATED (0x60) message — basic battery and placement info.

import Foundation

/// Decodes a STATUS_UPDATED (0x60) message payload.
///
/// Payload layout:
/// ```
/// [0] Battery Left    (0-100)
/// [1] Battery Right   (0-100)
/// [2] Status flags
/// ```
struct StatusUpdateDecoder {

    let batteryLeft: Int
    let batteryRight: Int
    let statusFlags: UInt8

    init(payload: [UInt8]) throws {
        guard payload.count >= 3 else {
            throw BudsError.payloadMalformed
        }
        self.batteryLeft = Int(payload[0])
        self.batteryRight = Int(payload[1])
        self.statusFlags = payload[2]
    }

    /// Apply decoded values to device state.
    func apply(to state: DeviceState) {
        state.batteryLeft = BatteryState(
            level: batteryLeft, isCharging: false, batteryType: nil)
        state.batteryRight = BatteryState(
            level: batteryRight, isCharging: false, batteryType: nil)
    }
}

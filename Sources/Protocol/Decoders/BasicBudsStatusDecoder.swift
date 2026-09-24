import Foundation

/// The battery and placement prefix shared by the non-legacy Buds status
/// packets. Model-specific settings after this prefix are deliberately ignored.
struct BasicBudsStatusDecoder {
    let revision: Int
    let left: Int
    let right: Int
    let chargingCase: Int
    let placement: UInt8

    init(payload: [UInt8], extended: Bool) throws {
        let offset = extended ? 1 : 0
        guard payload.count >= (extended ? 8 : 7) else { throw BudsError.payloadMalformed }
        revision = Int(payload[0])
        left = Int(payload[1 + offset])
        right = Int(payload[2 + offset])
        placement = payload[5 + offset]
        chargingCase = Int(payload[6 + offset])
    }

    func apply(to state: DeviceState) {
        state.interfaceRevision = revision
        state.batteryLeft = BatteryState(level: left, isCharging: false, batteryType: nil)
        state.batteryRight = BatteryState(level: right, isCharging: false, batteryType: nil)
        state.batteryCase = BatteryState(level: chargingCase == 0 ? nil : chargingCase,
                                         isCharging: false, batteryType: nil)
        state.placementByte = placement
        state.wearingLeft = WearingState(rawValue: Int(placement >> 4)) ?? .unknown
        state.wearingRight = WearingState(rawValue: Int(placement & 15)) ?? .unknown
        state.hasReceivedStatus = true
    }
}

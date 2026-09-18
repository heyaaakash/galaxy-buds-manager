import Foundation

struct StatusUpdateDecoder {
    let payload: [UInt8]
    var batteryLeft: Int { Int(payload[1]) }
    var batteryRight: Int { Int(payload[2]) }
    var statusFlags: UInt8 { payload[5] }

    init(payload: [UInt8]) throws {
        guard payload.count >= 7, payload[0] < 1 || payload.count >= 8 else {
            throw BudsError.payloadMalformed
        }
        self.payload = payload
    }

    func apply(to state: DeviceState) {
        let charging = payload[0] >= 1 ? payload[7] : 0
        state.batteryLeft = BatteryState(level: batteryLeft, isCharging: charging & 16 != 0, batteryType: nil)
        state.batteryRight = BatteryState(level: batteryRight, isCharging: charging & 4 != 0, batteryType: nil)
        state.batteryCase = BatteryState(level: payload[6] == 0 ? nil : Int(payload[6]), isCharging: charging & 1 != 0, batteryType: nil)
        state.isCoupled = payload[3] == 1
        state.mainConnection = MainConnection(rawValue: Int(payload[4])) ?? .right
        state.placementByte = payload[5]
        state.wearingLeft = WearingState(rawValue: Int(payload[5] >> 4)) ?? .unknown
        state.wearingRight = WearingState(rawValue: Int(payload[5] & 15)) ?? .unknown
    }
}

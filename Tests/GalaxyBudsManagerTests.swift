// GalaxyBudsManagerTests.swift
// Unit tests for packet encoding/decoding and protocol state management.
//
// NOTE: These tests require Xcode to run (swift test requires the XCTest framework).
// If XCTest is not available (e.g. only Command Line Tools installed), this file
// still compiles as part of the main target. Run via Xcode or install full Xcode.

#if canImport(XCTest)
import XCTest
@testable import GalaxyBudsManager

// MARK: - CRC16 Tests

final class BudsCRC16Tests: XCTestCase {

    func testCRC16EmptyData() {
        let crc = BudsCRC16.compute([])
        XCTAssertEqual(crc, 0x0000, "CRC of empty data should be init value 0x0000")
    }

    func testCRC16EncodeDecode() {
        let original: UInt16 = 0x1234
        let encoded = BudsCRC16.encode(original)
        XCTAssertEqual(encoded.count, 2)
        XCTAssertEqual(encoded[0], 0x34, "Low byte")
        XCTAssertEqual(encoded[1], 0x12, "High byte")
    }

    func testCRC16Verify() {
        let messageId: BudsMessageId = .extendedStatusUpdated
        let payload: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let crc = BudsCRC16.compute(messageId: messageId, payload: payload)
        let encoded = BudsCRC16.encode(crc)
        XCTAssertTrue(BudsCRC16.verify(messageId: messageId, payload: payload, receivedCRC: encoded))
    }

    func testCRC16VerifyFails() {
        let messageId: BudsMessageId = .extendedStatusUpdated
        let payload: [UInt8] = [0x01, 0x02]
        let wrongCRC: [UInt8] = [0x00, 0x00]
        XCTAssertFalse(BudsCRC16.verify(messageId: messageId, payload: payload, receivedCRC: wrongCRC))
    }

    func testCRC16VerifyFailsWrongLength() {
        let messageId: BudsMessageId = .extendedStatusUpdated
        let payload: [UInt8] = [0x01]
        let shortCRC: [UInt8] = [0x00]
        XCTAssertFalse(BudsCRC16.verify(messageId: messageId, payload: payload, receivedCRC: shortCRC))
    }

    func testCRC16Deterministic() {
        let data: [UInt8] = [0x61, 0x0D, 0x01, 0x01, 0x64, 0x32, 0x01, 0x00]
        let crc1 = BudsCRC16.compute(data)
        let crc2 = BudsCRC16.compute(data)
        XCTAssertEqual(crc1, crc2, "CRC should be deterministic")
    }
}

// MARK: - Message Header Tests

final class BudsMessageHeaderTests: XCTestCase {

    func testHeaderEncodeDecode() {
        let header = BudsMessageHeader(payloadSize: 20, isResponse: false, isFragment: false)
        let encoded = header.encode()
        let decoded = BudsMessageHeader.decode(encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.payloadSize, 20)
        XCTAssertFalse(decoded!.isResponse)
        XCTAssertFalse(decoded!.isFragment)
    }

    func testHeaderResponse() {
        let header = BudsMessageHeader(payloadSize: 30, isResponse: true, isFragment: false)
        let encoded = header.encode()
        let decoded = BudsMessageHeader.decode(encoded)
        XCTAssertEqual(decoded!.payloadSize, 30)
        XCTAssertTrue(decoded!.isResponse)
    }

    func testHeaderFragment() {
        let header = BudsMessageHeader(payloadSize: 100, isResponse: false, isFragment: true)
        let encoded = header.encode()
        let decoded = BudsMessageHeader.decode(encoded)
        XCTAssertEqual(decoded!.payloadSize, 100)
        XCTAssertTrue(decoded!.isFragment)
    }

    func testHeaderMaxSize() {
        let header = BudsMessageHeader(payloadSize: 0x7FF, isResponse: false, isFragment: false)
        let encoded = header.encode()
        let decoded = BudsMessageHeader.decode(encoded)
        XCTAssertEqual(decoded!.payloadSize, 0x7FF)
    }

    func testHeaderTooShort() {
        XCTAssertNil(BudsMessageHeader.decode([0x01]))
    }
}

// MARK: - Message Encode/Decode Tests

final class BudsMessageTests: XCTestCase {

    func testEncodeDecodeRequest() {
        let msg = BudsMessage.request(.equalizer, payload: [0x03])
        let encoded = msg.encode()

        XCTAssertEqual(encoded.first, BudsConstants.som)
        XCTAssertEqual(encoded.last, BudsConstants.eom)
        XCTAssertEqual(encoded.count, msg.totalPacketSize)

        let decoded = BudsMessage.decode(encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.id, .equalizer)
        XCTAssertEqual(decoded!.type, .request)
        XCTAssertEqual(decoded!.payload, [0x03])
    }

    func testEncodeDecodeResponse() {
        let msg = BudsMessage.response(.extendedStatusUpdated, payload: [0x01, 0x02, 0x03])
        let encoded = msg.encode()
        let decoded = BudsMessage.decode(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.id, .extendedStatusUpdated)
        XCTAssertEqual(decoded!.type, .response)
        XCTAssertEqual(decoded!.payload, [0x01, 0x02, 0x03])
    }

    func testEncodeDecodeEmptyPayload() {
        let msg = BudsMessage.request(.findMyEarbudsStart)
        let encoded = msg.encode()
        let decoded = BudsMessage.decode(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.id, .findMyEarbudsStart)
        XCTAssertEqual(decoded!.payload.count, 0)
    }

    func testDecodeTooShort() {
        let data: [UInt8] = [0xFD, 0x03, 0x00]
        XCTAssertNil(BudsMessage.decode(data))
    }

    func testDecodeInvalidSOM() {
        let data: [UInt8] = [0xFE, 0x03, 0x00, 0x60, 0x00, 0x00, 0xDD]
        XCTAssertNil(BudsMessage.decode(data))
    }

    func testAck() {
        let ack = BudsMessage.ack(for: .statusUpdated)
        XCTAssertEqual(ack.id, .statusUpdated)
        XCTAssertEqual(ack.type, .response)
        XCTAssertEqual(ack.payload.count, 0)
    }

    func testDecodeChunkMultipleMessages() {
        let msg1 = BudsMessage.request(.equalizer, payload: [0x01])
        let msg2 = BudsMessage.request(.gameMode, payload: [0x00])
        var data = msg1.encode() + msg2.encode()

        let messages = BudsMessage.decodeChunk(&data)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].id, .equalizer)
        XCTAssertEqual(messages[1].id, .gameMode)
        XCTAssertEqual(data.count, 0)
    }

    func testDecodeChunkWithGarbage() {
        let msg = BudsMessage.request(.noiseControls, payload: [0x01])
        var garbage: [UInt8] = [0x00, 0xFF, 0xAB, 0xCD]
        garbage.append(contentsOf: msg.encode())

        let messages = BudsMessage.decodeChunk(&garbage)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].id, .noiseControls)
    }

    func testEncodeDecodeLargePayload() {
        let payload = [UInt8](repeating: 0xAA, count: 50)
        let msg = BudsMessage.request(.debugGetAllData, payload: payload)
        let encoded = msg.encode()
        let decoded = BudsMessage.decode(encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.payload, payload)
    }

    func testEncodeDecodeAllMessageIds() {
        // Smoke test: encode and decode every known message ID
        for id in [BudsMessageId.equalizer, .noiseControls, .gameMode,
                   .extendedStatusUpdated, .managerInfo, .findMyEarbudsStart] {
            let msg = BudsMessage.request(id, payload: [0x01])
            let decoded = BudsMessage.decode(msg.encode())
            XCTAssertNotNil(decoded, "Failed for \(id)")
            XCTAssertEqual(decoded!.id, id)
        }
    }
}

// MARK: - Decoder Tests

final class ExtendedStatusDecoderTests: XCTestCase {
    func testBuds2ProRevision13Snapshot() throws {
        var payload = [UInt8](repeating: 0, count: 46)
        payload.replaceSubrange(0..<18, with: [13, 0, 100, 50, 1, 0, 0x12, 70, 1, 3, 0xBF, 0x12, 2, 0, 0x47, 1, 0x48, 1])
        payload[23] = 2; payload[26] = 1; payload[27] = 2; payload[28] = 1
        payload[33] = 1; payload[43] = 0x15; payload[45] = 1
        let decoder = try ExtendedStatusDecoder(payload: payload)
        let state = DeviceState()
        decoder.apply(to: state)
        XCTAssertEqual(state.batteryLeft.level, 100)
        XCTAssertEqual(state.batteryRight.level, 50)
        XCTAssertEqual(state.batteryCase.level, 70)
        XCTAssertTrue(state.batteryLeft.isCharging)
        XCTAssertTrue(state.batteryRight.isCharging)
        XCTAssertTrue(state.batteryCase.isCharging)
        XCTAssertEqual(state.wearingLeft, .wearing)
        XCTAssertEqual(state.wearingRight, .notWearing)
        XCTAssertEqual(state.noiseControlMode, .ambient)
        XCTAssertEqual(state.equalizerPreset, .dynamic)
        XCTAssertEqual(state.touchLeftAction, .voiceAssistant)
        XCTAssertEqual(state.touchRightAction, .noiseControl)
        XCTAssertFalse(state.touchpadLocked)
        XCTAssertEqual(state.colorLeft, .white)
        XCTAssertEqual(state.colorRight, .boraPurple)
        XCTAssertTrue(state.detectConversations)
        XCTAssertTrue(state.extraHighAmbient)
        XCTAssertTrue(state.hasReceivedStatus)
    }

    func testTruncatedRevision13Rejected() {
        XCTAssertThrowsError(try ExtendedStatusDecoder(payload: [13] + Array(repeating: 0, count: 33)))
    }

    func testRevisionZeroAndUnknownBattery() throws {
        var payload = [UInt8](repeating: 0, count: 34)
        payload[2] = 255; payload[7] = 255
        let state = DeviceState()
        try ExtendedStatusDecoder(payload: payload).apply(to: state)
        XCTAssertNil(state.batteryLeft.level)
        XCTAssertNil(state.batteryCase.level)
        XCTAssertFalse(state.extraHighAmbient)
    }
}

final class NoiseControlsUpdateDecoderTests: XCTestCase {

    func testDecodeANC() throws {
        let decoder = try NoiseControlsUpdateDecoder(payload: [0x01])
        XCTAssertEqual(decoder.mode, .anc)
    }

    func testDecodeAmbientWithVolume() throws {
        let decoder = try NoiseControlsUpdateDecoder(payload: [0x02, 0x02])
        XCTAssertEqual(decoder.mode, .ambient)
        XCTAssertEqual(decoder.volume, 0)
    }

    func testDecodeEmptyPayload() {
        XCTAssertThrowsError(try NoiseControlsUpdateDecoder(payload: []))
    }
}

final class TouchUpdatedDecoderTests: XCTestCase {

    func testDecode() throws {
        let decoder = try TouchUpdatedDecoder(payload: [0x01, 0x53])
        XCTAssertTrue(decoder.touchpadLocked)
    }

    func testDecodeTooShort() {
        XCTAssertThrowsError(try TouchUpdatedDecoder(payload: []))
    }
}

final class SerialNumberDecoderTests: XCTestCase {

    func testDecode() throws {
        let payload = Array("LEFT1234567RIGHT456789".utf8)
        let decoder = try SerialNumberDecoder(payload: payload)
        XCTAssertEqual(decoder.serialLeft, "LEFT1234567")
        XCTAssertEqual(decoder.serialRight, "RIGHT456789")
    }
}

final class FitTestResultDecoderTests: XCTestCase {

    func testPassed() throws {
        let decoder = try FitTestResultDecoder(payload: [1, 1])
        XCTAssertEqual(decoder.result, .passed)
    }

    func testFailedLeft() throws {
        let decoder = try FitTestResultDecoder(payload: [0, 1])
        XCTAssertEqual(decoder.result, .failedLeft)
    }

    func testFailedBoth() throws {
        let decoder = try FitTestResultDecoder(payload: [0, 0])
        XCTAssertEqual(decoder.result, .failedBoth)
    }
}

final class ConnectionUpdateDecoderTests: XCTestCase {

    func testDecode() throws {
        let decoder = try ConnectionUpdateDecoder(payload: [0x01, 0x01])
        XCTAssertEqual(decoder.mainConnection, .left)
        XCTAssertTrue(decoder.isCoupled)
    }

    func testDecodeSingleByte() throws {
        let decoder = try ConnectionUpdateDecoder(payload: [0x00])
        XCTAssertEqual(decoder.mainConnection, .right)
        XCTAssertFalse(decoder.isCoupled)
    }
}

// MARK: - Encoder Tests

final class ProtocolEncoderTests: XCTestCase {

    func testEqualizerEncoder() {
        let msg = EqualizerEncoder.encode(preset: .dynamic)
        XCTAssertEqual(msg.id, .equalizer)
        XCTAssertEqual(msg.payload, [0x03])
    }

    func testNoiseControlEncoder() {
        XCTAssertEqual(NoiseControlEncoder.encode(mode: .anc).payload, [0x01])
        XCTAssertEqual(NoiseControlEncoder.encode(mode: .ambient).payload, [0x02])
        XCTAssertEqual(NoiseControlEncoder.encode(mode: .off).payload, [0x00])
    }

    func testAmbientVolumeEncoder() {
        XCTAssertEqual(AmbientEncoder.setVolume(2).payload, [0x02])
        XCTAssertEqual(AmbientEncoder.setVolume(10).payload, [0x02]) // clamped
        XCTAssertEqual(AmbientEncoder.setVolume(-5).payload, [0x00]) // clamped
    }

    func testTouchpadLockEncoder() {
        XCTAssertEqual(TouchpadEncoder.lock(true).payload, [0, 1, 1, 1, 1, 1, 1])
        XCTAssertEqual(TouchpadEncoder.lock(false).payload, [1, 1, 1, 1, 1, 1, 1])
    }

    func testTouchpadActionsEncoder() {
        let msg = TouchpadEncoder.setActions(left: .noiseControl, right: .volume)
        XCTAssertEqual(msg.payload, [2, 3])
    }

    func testManagerInfoEncoder() {
        let msg = ManagerInfoEncoder.encode()
        XCTAssertEqual(msg.id, .managerInfo)
        XCTAssertEqual(msg.payload.count, 3)
    }

    func testUpdateTimeEncoder() {
        let msg = UpdateTimeEncoder.encode()
        XCTAssertEqual(msg.id, .updateTime)
        XCTAssertEqual(msg.payload.count, 12)
    }

    func testFindMyEarbudsEncoder() {
        XCTAssertEqual(FindMyEarbudsEncoder.start().id, .findMyEarbudsStart)
        XCTAssertEqual(FindMyEarbudsEncoder.stop().id, .findMyEarbudsStop)
    }

    func testMuteEncoder() {
        let msg = FindMyEarbudsEncoder.mute(left: true, right: false)
        XCTAssertEqual(msg.payload, [0x01, 0x00])
    }

    func testSpatialAudioEncoder() {
        XCTAssertEqual(SpatialAudioEncoder.setEnabled(true).payload, [0x01])
        XCTAssertEqual(SpatialAudioEncoder.setEnabled(false).payload, [0x00])
    }

    func testAmbientCustomizeEncoder() {
        let msg = AmbientEncoder.customizeAmbient(left: 1, center: 2, right: 3)
        XCTAssertEqual(msg.payload, [1, 1, 2, 2])
    }

    func testResetEncoder() {
        XCTAssertEqual(DeviceManagementEncoder.reset().id, .reset)
        XCTAssertEqual(DeviceManagementEncoder.reset().payload.count, 0)
    }

    func testRenameEncoder() {
        let msg = DeviceManagementEncoder.rename(name: "My Buds")
        XCTAssertEqual(msg.id, .getPersonalName)
        let nameBytes = Array(msg.payload.dropLast())
        XCTAssertEqual(String(bytes: nameBytes, encoding: .utf8), "My Buds")
    }
}

// MARK: - DeviceState Tests

final class DeviceStateTests: XCTestCase {

    func testAverageBattery() {
        let state = DeviceState()
        state.batteryLeft = BatteryState(level: 80, isCharging: false, batteryType: nil)
        state.batteryRight = BatteryState(level: 60, isCharging: false, batteryType: nil)
        state.batteryCase = BatteryState(level: 40, isCharging: false, batteryType: nil)
        XCTAssertEqual(state.averageBattery, 70)
    }

    func testAverageBatteryNoData() {
        XCTAssertNil(DeviceState().averageBattery)
    }

    func testAllInCase() {
        let state = DeviceState()
        state.wearingLeft = .inCase
        state.wearingRight = .inCase
        XCTAssertTrue(state.allInCase)
    }

    func testAllInCaseMixed() {
        let state = DeviceState()
        state.wearingLeft = .inCase
        state.wearingRight = .wearing
        XCTAssertFalse(state.allInCase)
    }

    func testIsAnyBudWorn() {
        let state = DeviceState()
        state.wearingLeft = .wearing
        XCTAssertTrue(state.isAnyBudWorn)
    }

    func testNoiseControlActive() {
        let state = DeviceState()
        XCTAssertFalse(state.isNoiseControlActive)
        state.noiseControlMode = .anc
        XCTAssertTrue(state.isNoiseControlActive)
    }

    func testReset() {
        let state = DeviceState()
        state.firmwareVersion = "R510XXU1AWA4"
        state.serialNumber = "RF123456"
        state.batteryLeft = BatteryState(level: 80, isCharging: false, batteryType: nil)
        state.connectionState = .connected

        state.reset()

        XCTAssertEqual(state.connectionState, .disconnected)
        XCTAssertNil(state.batteryLeft.level)
        XCTAssertEqual(state.firmwareVersion, "")
        XCTAssertEqual(state.serialNumber, "")
    }
}

// MARK: - Message ID Tests

final class BudsMessageIdTests: XCTestCase {

    func testAllCasesUnique() {
        let values = BudsMessageId.allCases.map(\.rawValue)
        XCTAssertEqual(values.count, Set(values).count)
    }

    func testFromKnownValue() {
        XCTAssertEqual(BudsMessageId.from(0x61), .extendedStatusUpdated)
    }

    func testFromUnknownValue() {
        XCTAssertEqual(BudsMessageId.from(0xFF), .unknown)
    }
}

// MARK: - BudsDeviceSpec Tests

final class BudsDeviceSpecTests: XCTestCase {

    func testSupports() {
        let spec = BudsDeviceSpec()
        XCTAssertTrue(spec.supports(.noiseControl))
        XCTAssertTrue(spec.supports(.anc))
        XCTAssertTrue(spec.supports(.gamingMode))
        XCTAssertTrue(spec.supports(.caseBattery))
    }

    func testSupportsWithRevision() {
        let spec = BudsDeviceSpec()
        XCTAssertTrue(spec.supports(.extraClearCallSound, firmwareRevision: 13))
        XCTAssertFalse(spec.supports(.extraClearCallSound, firmwareRevision: 10))
    }

    func testMaximumAmbientVolume() {
        XCTAssertEqual(BudsDeviceSpec().maximumAmbientVolume, 2)
    }
}

// MARK: - CapabilityMatrix Tests

final class CapabilityMatrixTests: XCTestCase {

    func testMatrixNotEmpty() {
        XCTAssertFalse(CapabilityMatrix.matrix.isEmpty)
    }

    func testSummary() {
        let summary = CapabilityMatrix.summary()
        XCTAssertTrue(summary.contains("Readable:"))
        XCTAssertTrue(summary.contains("Writable:"))
    }
}

// MARK: - ConnectionState & Backoff Tests

final class ConnectionStateAndBackoffTests: XCTestCase {

    func testConnectionStateProperties() {
        let connected = ConnectionState.connected
        XCTAssertTrue(connected.isConnected)
        XCTAssertFalse(connected.isConnectingOrReconnecting)
        XCTAssertEqual(connected.description, "● Galaxy Buds2 Pro")

        let connecting = ConnectionState.connecting
        XCTAssertFalse(connecting.isConnected)
        XCTAssertTrue(connecting.isConnectingOrReconnecting)
        XCTAssertEqual(connecting.description, "Connecting…")

        let reconnecting = ConnectionState.reconnecting(attempt: 3)
        XCTAssertFalse(reconnecting.isConnected)
        XCTAssertTrue(reconnecting.isConnectingOrReconnecting)
        XCTAssertEqual(reconnecting.description, "Reconnecting… (attempt 3)")

        let disconnected = ConnectionState.disconnected
        XCTAssertFalse(disconnected.isConnected)
        XCTAssertFalse(disconnected.isConnectingOrReconnecting)
        XCTAssertEqual(disconnected.description, "Galaxy Buds2 Pro unavailable")

        let error = ConnectionState.error("Test timeout")
        XCTAssertEqual(error.errorDescription, "Test timeout")
    }

    func testExponentialBackoffDelays() {
        func backoffDelay(attempt: Int) -> TimeInterval {
            let exponent = min(attempt - 1, 5)
            return min(60.0, 2.0 * pow(2.0, Double(max(0, exponent))))
        }

        XCTAssertEqual(backoffDelay(attempt: 1), 2.0)
        XCTAssertEqual(backoffDelay(attempt: 2), 4.0)
        XCTAssertEqual(backoffDelay(attempt: 3), 8.0)
        XCTAssertEqual(backoffDelay(attempt: 4), 16.0)
        XCTAssertEqual(backoffDelay(attempt: 5), 32.0)
        XCTAssertEqual(backoffDelay(attempt: 6), 60.0)
        XCTAssertEqual(backoffDelay(attempt: 10), 60.0)
    }
}

// MARK: - CommandQueue Tests

final class CommandQueueTests: XCTestCase {

    func testCommandQueueEnqueueAndResponse() async {
        let queue = CommandQueue()
        var sentMessages: [BudsMessage] = []

        await queue.start { msg in
            sentMessages.append(msg)
        }

        let expectation = expectation(description: "Command acknowledged")
        let requestMsg = BudsMessage.request(.equalizer, payload: [0x02])

        await queue.enqueue(requestMsg, timeout: 2.0) { result in
            switch result {
            case .success(let resp):
                XCTAssertEqual(resp.id, .equalizer)
                expectation.fulfill()
            case .failure(let err):
                XCTFail("Expected success but got \(err)")
            }
        }

        XCTAssertEqual(sentMessages.count, 1)
        XCTAssertEqual(sentMessages[0].id, .equalizer)

        let responseMsg = BudsMessage.response(.equalizer, payload: [0x02])
        await queue.handleResponse(responseMsg)

        await fulfillment(of: [expectation], timeout: 1.0)
        await queue.stop()
    }

    func testCommandQueueStopCancelsPending() async {
        let queue = CommandQueue()
        await queue.start { _ in }

        let expectation = expectation(description: "Command cancelled on stop")
        let requestMsg = BudsMessage.request(.gameMode, payload: [0x01])

        await queue.enqueue(requestMsg, timeout: 5.0) { result in
            switch result {
            case .failure(let err):
                XCTAssertEqual(err, .disconnected)
                expectation.fulfill()
            case .success:
                XCTFail("Expected failure on stop")
            }
        }

        await queue.stop()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

// MARK: - TouchAction Tests

final class TouchActionTests: XCTestCase {

    func testAllCasesUnique() {
        let values = TouchAction.allCases.map(\.rawValue)
        XCTAssertEqual(values.count, Set(values).count)
    }
}

#endif  // canImport(XCTest)


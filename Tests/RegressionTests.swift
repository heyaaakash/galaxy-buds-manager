#if canImport(Testing)
import Testing
import Foundation
@testable import GalaxyBudsManager

@Suite("Buds2 Pro protocol regressions", .serialized)
struct RegressionTests {
    @Test func knownCRCVector() {
        #expect(BudsCRC16.compute(Array("123456789".utf8)) == 0x31C3)
        // Published packet body and checksum, independent of this encoder.
        let body: [UInt8] = [0x61, 2, 0, 0x4B, 0x5F, 1, 0, 0, 0, 1, 5, 0, 2, 0, 0x13]
        #expect(BudsCRC16.encode(BudsCRC16.compute(body)) == [0x0F, 0xF3])
    }

    @Test func corruptPacketRejectedAndStreamRecovers() {
        var corrupt = BudsMessage.request(.equalizer, payload: [3]).encode()
        corrupt[4] ^= 1
        #expect(BudsMessage.decode(corrupt) == nil)
        var stream = corrupt + BudsMessage.request(.noiseControls, payload: [1]).encode()
        let decoded = BudsMessage.decodeChunk(&stream)
        #expect(decoded.count == 1)
        #expect(decoded.first?.id == .noiseControls)
        #expect(stream.isEmpty)
    }

    @Test func fragmentedTransportAndUnknownID() {
        let raw = BudsMessage(id: .unknown, payload: [1, 2], rawID: 0xF1).encode()
        var buffer = Array(raw.prefix(5))
        #expect(BudsMessage.decodeChunk(&buffer).isEmpty)
        buffer += raw.dropFirst(5)
        let decoded = BudsMessage.decodeChunk(&buffer)
        #expect(decoded.first?.rawID == 0xF1)
        #expect(decoded.first?.encode() == raw)
        #expect(buffer.isEmpty)
    }

    @Test func controlPayloads() {
        #expect(ManagerInfoEncoder.encode().payload == [1, 2, 0])
        #expect(TouchpadEncoder.setActions(left: .noiseControl, right: .volume).payload == [2, 3])
        #expect(TouchpadEncoder.lock(false).payload == [1, 1, 1, 1, 1, 1, 1])
        #expect(TouchpadEncoder.lock(true, flags: 0x08, revision: 0).payload == [0, 1, 0, 0, 0])
        #expect(FitTestEncoder.startCheck().payload == [1])
        #expect(AmbientEncoder.setVolume(100).payload == [2])
        #expect(AmbientEncoder.setVolume(-1).payload == [0])
        #expect(UpdateTimeEncoder.encode(date: Date(timeIntervalSince1970: 1)).payload.prefix(8) == [0xE8, 3, 0, 0, 0, 0, 0, 0])
    }

    @MainActor @Test func findMyEarbudsStartsFireAndForget() async {
        let state = DeviceState()
        state.connectionState = .connected
        state.hasReceivedStatus = true
        let proto = BudsProtocol(deviceState: state)
        var sent = [[UInt8]]()
        await proto.start { sent.append($0); return true }

        await proto.startFindMyEarbuds()
        #expect(sent.count == 1)
        #expect(BudsMessage.decode(sent[0])?.id == .findMyEarbudsStart)
        #expect(state.findMyActive)
        #expect(state.pendingCommands.isEmpty)

        await proto.stopFindMyEarbuds()
        #expect(sent.count == 2)
        #expect(BudsMessage.decode(sent[1])?.id == .findMyEarbudsStop)
        #expect(!state.findMyActive)

        proto.stop()
    }

    @MainActor @Test func findMyEarbudsRingsWhileWearingWhenSupported() async {
        let state = DeviceState()
        state.connectionState = .connected
        state.hasReceivedStatus = true
        state.interfaceRevision = 4
        state.wearingLeft = .wearing
        let proto = BudsProtocol(deviceState: state)
        var sent = [[UInt8]]()
        await proto.start { sent.append($0); return true }

        await proto.startFindMyEarbuds()
        #expect(sent.count == 1)
        #expect(BudsMessage.decode(sent[0])?.id == .findMyEarbudsOnWearingStart)
        #expect(state.findMyActive)

        proto.stop()
    }

    @MainActor @Test func findMyEarbudsRefusesLoudRingWhileWornOnOldFirmware() async {
        let state = DeviceState()
        state.connectionState = .connected
        state.hasReceivedStatus = true
        state.interfaceRevision = 3
        state.wearingRight = .wearing
        let proto = BudsProtocol(deviceState: state)
        var sent = [[UInt8]]()
        var errors = [String]()
        proto.onError = { errors.append($0) }
        await proto.start { sent.append($0); return true }

        await proto.startFindMyEarbuds()
        #expect(sent.isEmpty)
        #expect(!state.findMyActive)
        #expect(errors.count == 1)

        proto.stop()
    }

    static func status(revision: UInt8 = 13) -> [UInt8] {
        var p = [UInt8](repeating: 0, count: 46)
        p.replaceSubrange(0..<18, with: [revision, 0, 85, 90, 1, 0, 0x12, 255, 1, 3, 0xBF, 0x23, 1, 0, 0x46, 1, 0x48, 1])
        p[23] = 2; p[26] = 1; p[27] = 2; p[28] = 1; p[33] = 1; p[43] = 0x15; p[45] = 1
        return p
    }

    @Test func extendedStatusLayout() throws {
        let state = DeviceState()
        try ExtendedStatusDecoder(payload: Self.status()).apply(to: state)
        #expect(state.batteryLeft.level == 85)
        #expect(state.batteryRight.level == 90)
        #expect(state.batteryCase.level == nil)
        #expect(state.batteryLeft.isCharging && state.batteryRight.isCharging && state.batteryCase.isCharging)
        #expect(state.noiseControlMode == .anc && !state.ambientEnabled)
        #expect(state.equalizerPreset == .dynamic)
        #expect(state.touchLeftAction == .noiseControl && state.touchRightAction == .volume)
        #expect(!state.touchpadLocked)
        #expect(state.wearingLeft == .wearing && state.wearingRight == .notWearing)
        #expect(state.colorLeft == .graphite && state.colorRight == .boraPurple)
        #expect(state.detectConversations && state.detectConversationsDuration == 2)
        #expect(state.sidetoneEnabled && state.ancWithOneEarbud && state.extraHighAmbient)
    }

    @Test(arguments: [0, 1, 3, 8, 11, 13]) func revisionLengths(revision: Int) throws {
        let required = [0: 34, 1: 41, 3: 42, 8: 43, 11: 44, 13: 45][revision]!
        let bytes = Array(Self.status(revision: UInt8(revision)).prefix(required))
        _ = try ExtendedStatusDecoder(payload: bytes)
        #expect(throws: (any Error).self) { try ExtendedStatusDecoder(payload: Array(bytes.dropLast())) }
    }

    @Test func basicStatusLayout() throws {
        let state = DeviceState()
        try StatusUpdateDecoder(payload: [1, 45, 67, 1, 1, 0x33, 72, 0x14]).apply(to: state)
        #expect(state.batteryLeft.level == 45 && state.batteryRight.level == 67 && state.batteryCase.level == 72)
        #expect(state.batteryLeft.isCharging && state.batteryRight.isCharging && !state.batteryCase.isCharging)
        #expect(state.mainConnection == .left && state.allInCase)
        #expect(throws: (any Error).self) { try StatusUpdateDecoder(payload: [1, 45, 67]) }
    }

    @Test func liveFirmwareAndNoiseFixtures() throws {
        // Non-identifying fields from the physical SM-R510 session.
        let version = try VersionInfoDecoder(payload: [0, 0, 1, 0xB3, 1, 1, 0xB3, 1, 0, 0])
        #expect(version.firmwareVersion == "R510XXU0AZD1")
        let state = DeviceState()
        state.ambientVolume = 1
        try NoiseControlsUpdateDecoder(payload: [0, 0x21, 1, 0x66, 0]).apply(to: state)
        #expect(state.ambientVolume == 1)
        #expect(state.noiseControlMode == .off)
    }

    @Test func fixedWidthSerialAndCycleData() throws {
        let serial = try SerialNumberDecoder(payload: Array("LEFT1234567RIGHT123456".utf8))
        #expect(serial.serialLeft == "LEFT1234567" && serial.serialRight == "RIGHT123456")
        let cradle = try CradleSerialNumberDecoder(payload: Array("1305.1020CRADLE12345".utf8))
        #expect(cradle.serialNumber == "CRADLE12345")
        let cycles = try BatteryCycleDecoder(payload: [0,0,0,0,0,0,0x27,0x10, 0,0,0,0,0,0,0x4E,0x20])
        #expect(cycles.leftCycles == 1 && cycles.rightCycles == 2)
    }

    @Test func additionalControlPayloads() {
        #expect(AmbientEncoder.customize(enabled: true, left: 4, right: 9, tone: 8, maximum: 4).payload == [1, 4, 4, 4])
        #expect(AmbientEncoder.setVolume(4, maximum: 3).payload == [3])
        #expect(DeviceManagementEncoder.setSeamlessConnection(true).payload == [0])
        #expect(DeviceManagementEncoder.setSeamlessConnection(false).payload == [1])
    }

    @Test func unrelatedNoiseNotificationDoesNotAcknowledge() async {
        let queue = CommandQueue()
        await queue.start { _ in }
        await queue.enqueue(.request(.noiseControls, payload: [1]))
        await queue.confirmNotification(.response(.noiseControls, payload: [0]))
        #expect(await queue.pendingCount == 1)
        await queue.confirmNotification(.response(.noiseControls, payload: [1]))
        #expect(await queue.pendingCount == 0)
        await queue.stop()
    }

    @Test func closedCaseDoesNotDisplayZeroPercent() throws {
        let state = DeviceState()
        var extended = Self.status()
        extended[7] = 0
        try ExtendedStatusDecoder(payload: extended).apply(to: state)
        #expect(state.batteryCase.level == nil)
        try StatusUpdateDecoder(payload: [1, 97, 97, 1, 1, 0x11, 0, 0]).apply(to: state)
        #expect(state.batteryCase.level == nil)
    }

    @Test func fitResults() throws {
        #expect(try FitTestResultDecoder(payload: [1, 1]).result == .passed)
        #expect(try FitTestResultDecoder(payload: [0, 1]).result == .failedLeft)
        #expect(try FitTestResultDecoder(payload: [1, 0]).result == .failedRight)
        #expect(try FitTestResultDecoder(payload: [0, 0]).result == .failedBoth)
        #expect(try FitTestResultDecoder(payload: [2, 2]).result == .unknown)
    }

    @Test func resetClearsSessionState() throws {
        let state = DeviceState()
        try ExtendedStatusDecoder(payload: Self.status()).apply(to: state)
        state.findMyActive = true; state.fitTestRunning = true; state.firmwareVersionLong = "old"
        state.reset()
        #expect(!state.hasReceivedStatus && !state.findMyActive && !state.fitTestRunning)
        #expect(state.batteryLeft.level == nil && state.firmwareVersionLong.isEmpty)
        #expect(!state.detectConversations && !state.sidetoneEnabled)
    }

    @Test func loggerJSONAndReplay() throws {
        ProtocolLogger.isEnabled = true
        defer { ProtocolLogger.isEnabled = false; ProtocolLogger.clear() }
        ProtocolLogger.clear()
        let message = BudsMessage.request(.equalizer, payload: [3])
        ProtocolLogger.logOutgoing(message)
        ProtocolLogger.logIncoming(message, rawBytes: message.encode())
        let data = try #require(ProtocolLogger.exportJSON())
        #expect(ProtocolLogger.loadReplayData(from: data) == [message.encode()])
    }

    @Test func queueReplacementAndRetryCleanup() async throws {
        let queue = CommandQueue()
        await queue.start { _ in }
        await queue.enqueue(.request(.equalizer), timeout: 0.01, maxRetries: 1)
        await queue.enqueue(.request(.equalizer, payload: [3]), timeout: 0.01, maxRetries: 1)
        #expect(await queue.pendingCount == 1)
        try await Task.sleep(nanoseconds: 1_200_000_000)
        await queue.handleResponse(.response(.equalizer))
        #expect(await queue.pendingCount == 0)
        await queue.stop()
        await queue.enqueue(.request(.equalizer))
        #expect(await queue.pendingCount == 0)
    }

    @MainActor @Test func acknowledgedSettingsAndOfflineGuard() async throws {
        let state = DeviceState()
        let proto = BudsProtocol(deviceState: state)
        var sent = [[UInt8]]()
        await proto.start { sent.append($0); return true }
        await proto.setEqualizer(preset: .dynamic)
        #expect(sent.isEmpty)
        state.connectionState = .connected
        state.hasReceivedStatus = true
        await proto.setEqualizer(preset: .dynamic)
        #expect(sent.count == 1)
        #expect(state.equalizerPreset == .disabled)
        proto.processData(BudsMessage.request(.universalAcknowledgement, payload: [0x86, 3]).encode())
        #expect(state.equalizerPreset == .dynamic)
        proto.stop()
        #expect(!state.hasReceivedStatus)
    }

    @MainActor @Test func touchLockAcknowledgementUsesCommandPolarity() async {
        let state = DeviceState()
        state.connectionState = .connected
        state.hasReceivedStatus = true
        let proto = BudsProtocol(deviceState: state)
        var sent = [[UInt8]]()
        await proto.start { sent.append($0); return true }

        await proto.setTouchpadLocked(true)
        #expect(sent.count == 1)
        #expect(!state.touchpadLocked)
        proto.processData(BudsMessage.request(
            .universalAcknowledgement,
            payload: [BudsMessageId.lockTouchpad.rawValue, 0, 1, 1, 1, 1, 1, 1]
        ).encode())
        #expect(state.touchpadLocked)
        #expect(state.touchEnabledFlags == 0x3F)

        proto.stop()
    }

    @MainActor @Test func touchGestureAcknowledgementKeepsSurfaceUnlocked() async {
        let state = DeviceState()
        state.connectionState = .connected
        state.hasReceivedStatus = true
        let proto = BudsProtocol(deviceState: state)
        await proto.start { _ in true }

        await proto.setTapEnabled(bit: 3, enabled: false)
        proto.processData(BudsMessage.request(
            .universalAcknowledgement,
            payload: [BudsMessageId.lockTouchpad.rawValue, 1, 0, 1, 1, 1, 1, 1]
        ).encode())
        #expect(!state.touchpadLocked)
        #expect(state.touchEnabledFlags == 0x37)

        proto.stop()
    }

    @MainActor @Test func touchActionAndEdgeTapAcknowledgements() async {
        let state = DeviceState()
        state.connectionState = .connected
        state.hasReceivedStatus = true
        let proto = BudsProtocol(deviceState: state)
        await proto.start { _ in true }

        await proto.setTouchActions(left: .noiseControl, right: .volume)
        proto.processData(BudsMessage.request(
            .universalAcknowledgement,
            payload: [BudsMessageId.setTouchpadOption.rawValue, 2, 3]
        ).encode())
        #expect(state.touchLeftAction == .noiseControl)
        #expect(state.touchRightAction == .volume)

        await proto.setDoubleTapVolume(true)
        proto.processData(BudsMessage.request(
            .universalAcknowledgement,
            payload: [BudsMessageId.outsideDoubleTap.rawValue, 1]
        ).encode())
        #expect(state.doubleTapVolume)

        proto.stop()
    }

    @MainActor @Test func deviceIdentification() {
        #expect(DiscoveredDevice.isGalaxyBudsName("Galaxy Buds2 Pro"))
        #expect(DiscoveredDevice.isGalaxyBudsName("Galaxy Buds 2 Pro (ABCD)"))
        #expect(!DiscoveredDevice.isGalaxyBudsName("Galaxy Buds3 Pro"))
        #expect(!DiscoveredDevice.isGalaxyBudsName("Someone's Buds"))
    }
}
#endif

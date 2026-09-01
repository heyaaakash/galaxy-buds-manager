// BudsProtocol.swift
// Protocol orchestrator — handles incoming message dispatch, outgoing command construction,
// and state synchronization. Sits between the Bluetooth layer and the UI.

import Foundation

/// Orchestrates the Samsung Galaxy Buds SPP protocol.
@MainActor
final class BudsProtocol {

    let deviceState: DeviceState
    private let commandQueue = CommandQueue()
    let spec = BudsDeviceSpec()
    private var sendHandler: (([UInt8]) async -> Void)?
    private var handshakeComplete = false

    init(deviceState: DeviceState) {
        self.deviceState = deviceState
    }

    private var incomingBuffer: [UInt8] = []

    // MARK: - Lifecycle

    func start(sendHandler: @escaping ([UInt8]) async -> Void) async {
        self.sendHandler = sendHandler
        handshakeComplete = false
        incomingBuffer.removeAll()

        await commandQueue.start { message in
            ProtocolLogger.logOutgoing(message)
            let raw = message.encode()
            await sendHandler(raw)
        }
        ProtocolLogger.log(.info, "Protocol layer started for \(spec.deviceBaseName)")
    }

    func stop() {
        Task { await commandQueue.stop() }
        handshakeComplete = false
        incomingBuffer.removeAll()
        ProtocolLogger.log(.info, "Protocol layer stopped")
    }

    // MARK: - Incoming

    func processData(_ data: [UInt8]) {
        incomingBuffer.append(contentsOf: data)
        // Guard against memory explosion if corrupt noise
        if incomingBuffer.count > 65536 {
            incomingBuffer.removeAll()
            return
        }

        let messages = BudsMessage.decodeChunk(&incomingBuffer)
        for message in messages {
            ProtocolLogger.logIncoming(message, rawBytes: message.encode())
            processMessage(message)
        }
    }

    private func processMessage(_ message: BudsMessage) {
        switch message.id {
        // Status
        case .extendedStatusUpdated: handleExtendedStatusUpdated(message)
        case .statusUpdated:         handleStatusUpdated(message)
        case .connectionUpdated:     handleConnectionUpdated(message)
        case .versionInfo:           handleVersionInfo(message)
        case .versionInfoLong:       handleVersionInfoLong(message)

        // Noise control
        case .noiseControlsUpdate:   handleNoiseControlsUpdate(message)
        case .ambientModeUpdated:    handleAmbientModeUpdated(message)

        // Touch
        case .touchUpdated:          handleTouchUpdated(message)

        // Mute
        case .muteEarbudStatusUpdated: handleMuteStatus(message)

        // Fit test
        case .checkFitResult:        handleFitTestResult(message)

        // Debug responses
        case .debugSerialNumber, .debugBuildInfo, .debugGetVersion, .debugSku,
             .debugGetAllData, .cradleSerialNumber, .socBatteryCycle, .batteryType:
            handleDebugResponse(message)

        // Default
        default:
            if message.type == .response {
                Task { await commandQueue.handleResponse(message) }
                ProtocolLogger.log(.info, "Command response: \(message.id)")
            } else {
                ProtocolLogger.log(.info, "Unhandled message: \(message.id) (\(message.payload.count) bytes)")
                sendAcknowledgement(for: message.id)
            }
        }
    }

    // MARK: - Handlers

    private func handleExtendedStatusUpdated(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)

        do {
            let decoder = try ExtendedStatusDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
            ProtocolLogger.log(.info, "Extended status:\n\(decoder.debugDescription)")
        } catch {
            ProtocolLogger.log(.error, "Failed to decode extended status: \(error)")
        }

        if !handshakeComplete {
            Task {
                await sendFireAndForget(ManagerInfoEncoder.encode())
                await sendFireAndForget(UpdateTimeEncoder.encode())
                handshakeComplete = true
                ProtocolLogger.log(.info, "Manager handshake sent")
            }
        }

        Task { await requestInitialData() }
    }

    private func handleStatusUpdated(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)
        if let payload = message.payload as [UInt8]?,
           payload.count >= 3 {
            deviceState.batteryLeft = BatteryState(level: Int(payload[0]), isCharging: false, batteryType: nil)
            deviceState.batteryRight = BatteryState(level: Int(payload[1]), isCharging: false, batteryType: nil)
        }
    }

    private func handleConnectionUpdated(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)
        do {
            let decoder = try ConnectionUpdateDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode connection update: \(error)")
        }
    }

    private func handleVersionInfo(_ message: BudsMessage) {
        do {
            let decoder = try VersionInfoDecoder(payload: message.payload)
            decoder.apply(to: deviceState, isLong: false)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode version info: \(error)")
        }
    }

    private func handleVersionInfoLong(_ message: BudsMessage) {
        do {
            let decoder = try VersionInfoDecoder(payload: message.payload)
            decoder.apply(to: deviceState, isLong: true)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode version info long: \(error)")
        }
    }

    private func handleNoiseControlsUpdate(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)
        do {
            let decoder = try NoiseControlsUpdateDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode noise controls: \(error)")
        }
    }

    private func handleAmbientModeUpdated(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)
        do {
            let decoder = try AmbientModeUpdatedDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode ambient mode: \(error)")
        }
    }

    private func handleTouchUpdated(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)
        do {
            let decoder = try TouchUpdatedDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode touch update: \(error)")
        }
    }

    private func handleMuteStatus(_ message: BudsMessage) {
        sendAcknowledgement(for: message.id)
        do {
            let decoder = try MuteEarbudStatusDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
        } catch {
            ProtocolLogger.log(.error, "Failed to decode mute status: \(error)")
        }
    }

    private func handleFitTestResult(_ message: BudsMessage) {
        do {
            let decoder = try FitTestResultDecoder(payload: message.payload)
            decoder.apply(to: deviceState)
            ProtocolLogger.log(.info, "Fit test result: \(decoder.result.description)")
        } catch {
            ProtocolLogger.log(.error, "Failed to decode fit test result: \(error)")
        }
    }

    private func handleDebugResponse(_ message: BudsMessage) {
        switch message.id {
        case .debugSerialNumber:
            if let dec = try? SerialNumberDecoder(payload: message.payload) { dec.apply(to: deviceState) }
        case .debugBuildInfo:
            if let dec = try? BuildInfoDecoder(payload: message.payload) { dec.apply(to: deviceState) }
        case .debugGetVersion:
            if let dec = try? DebugVersionDecoder(payload: message.payload) {
                if deviceState.firmwareVersion.isEmpty {
                    deviceState.firmwareVersion = dec.version
                }
            }
        case .debugSku:
            if let dec = try? SkuDecoder(payload: message.payload) { dec.apply(to: deviceState) }
        case .debugGetAllData:
            let dec = DebugAllDataDecoder(payload: message.payload)
            dec.apply(to: deviceState)
        case .cradleSerialNumber:
            if let dec = try? CradleSerialNumberDecoder(payload: message.payload) { dec.apply(to: deviceState) }
        case .socBatteryCycle:
            if let dec = try? BatteryCycleDecoder(payload: message.payload) { dec.apply(to: deviceState) }
        case .batteryType:
            ProtocolLogger.log(.info, "Battery type response: \(message.payload.count) bytes")
        default:
            break
        }
    }

    // MARK: - Request Data

    /// Public entry point called by AppState after connection.
    func requestInitialState() async {
        handshakeComplete = false
        ProtocolLogger.log(.info, "Sending Galaxy Buds2 Pro handshake & initial queries...")
        await sendFireAndForget(ManagerInfoEncoder.encode())
        await sendFireAndForget(UpdateTimeEncoder.encode())
        await sendFireAndForget(DebugEncoder.debugGetVersion())
        await sendFireAndForget(DebugEncoder.debugSerialNumber())
        handshakeComplete = true
    }

    private func requestInitialData() async {
        await sendFireAndForget(DebugEncoder.debugGetVersion())
        await sendFireAndForget(DebugEncoder.debugSerialNumber())
        await sendFireAndForget(UpdateTimeEncoder.encode())
    }

    // MARK: - Sending

    func sendCommand(
        _ message: BudsMessage,
        completion: ((Result<BudsMessage, BudsError>) -> Void)? = nil
    ) async {
        await commandQueue.enqueue(message, completion: completion)
    }

    func sendFireAndForget(_ message: BudsMessage) async {
        ProtocolLogger.logOutgoing(message)
        let raw = message.encode()
        await sendHandler?(raw)
    }

    private func sendAcknowledgement(for messageId: BudsMessageId) {
        Task {
            let ack = BudsMessage.ack(for: messageId)
            let raw = ack.encode()
            await sendHandler?(raw)
        }
    }

    // MARK: - Public API

    // Noise Control
    func setNoiseControl(mode: NoiseControlMode) async {
        await sendFireAndForget(NoiseControlEncoder.encode(mode: mode))
    }

    func setAncWithOneEarbud(_ enabled: Bool) async {
        await sendFireAndForget(AncEncoder.setAncWithOneEarbud(enabled))
    }

    func setAdjustSoundSync(_ enabled: Bool) async {
        await sendFireAndForget(AncEncoder.setAdjustSoundSync(enabled))
    }

    // Equalizer
    func setEqualizer(preset: EqualizerPreset) async {
        await sendFireAndForget(EqualizerEncoder.encode(preset: preset))
    }

    // Ambient
    func setAmbientVolume(_ volume: Int) async {
        await sendFireAndForget(AmbientEncoder.setVolume(volume))
    }

    func setExtraHighAmbient(_ enabled: Bool) async {
        await sendFireAndForget(AmbientEncoder.setExtraHigh(enabled))
    }

    func customizeAmbient(left: UInt8, center: UInt8, right: UInt8) async {
        await sendFireAndForget(AmbientEncoder.customizeAmbient(left: left, center: center, right: right))
    }

    func setNoiseReductionLevel(_ level: UInt8) async {
        await sendFireAndForget(AmbientEncoder.setNoiseReductionLevel(level))
    }

    func setAmplifyAmbient(_ enabled: Bool) async {
        await sendFireAndForget(AmbientEncoder.setAmplifyAmbient(enabled))
    }

    // Touch
    func setTouchpadLocked(_ locked: Bool) async {
        await sendFireAndForget(TouchpadEncoder.lock(locked))
    }

    func setTouchActions(left: TouchAction, right: TouchAction) async {
        await sendFireAndForget(TouchpadEncoder.setActions(left: left, right: right))
    }

    // Find My Earbuds
    func startFindMyEarbuds() async {
        await sendFireAndForget(FindMyEarbudsEncoder.start())
    }

    func stopFindMyEarbuds() async {
        await sendFireAndForget(FindMyEarbudsEncoder.stop())
    }

    func muteFindMyEarbud(left: Bool, right: Bool) async {
        await sendFireAndForget(FindMyEarbudsEncoder.mute(left: left, right: right))
    }

    // Audio Features
    func setSpatialAudio(_ enabled: Bool) async {
        await sendFireAndForget(SpatialAudioEncoder.setEnabled(enabled))
    }

    func setGameMode(_ enabled: Bool) async {
        await sendFireAndForget(GameModeEncoder.setEnabled(enabled))
    }

    func setAdaptiveVolume(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setAdaptiveVolume(enabled))
    }

    func setAdaptiveEq(_ enabled: Bool) async {
        await sendFireAndForget(AdaptiveEqEncoder.setEnabled(enabled))
    }

    // Voice & Call
    func setDetectConversations(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setDetectConversations(enabled))
    }

    func setDetectConversationsDuration(_ duration: UInt8) async {
        await sendFireAndForget(VoiceCallEncoder.setDetectConversationsDuration(duration))
    }

    func setSidetone(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setSidetone(enabled))
    }

    func setInBandRingtone(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setInBandRingtone(enabled))
    }

    func setVoiceNotification(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setVoiceNotification(enabled))
    }

    func setPauseMediaOnRemoval(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setPauseMediaOnRemoval(enabled))
    }

    func setExtraClearCallSound(_ enabled: Bool) async {
        await sendFireAndForget(VoiceCallEncoder.setExtraClearCallSound(enabled))
    }

    // Device Management
    func resetDevice() async {
        await sendFireAndForget(DeviceManagementEncoder.reset())
    }

    func rebootDevice() async {
        await sendFireAndForget(DeviceManagementEncoder.reboot())
    }

    func powerOffDevice() async {
        await sendFireAndForget(DeviceManagementEncoder.poweroff())
    }

    func renameDevice(name: String) async {
        await sendFireAndForget(DeviceManagementEncoder.rename(name: name))
    }

    func setSeamlessConnection(_ enabled: Bool) async {
        await sendFireAndForget(DeviceManagementEncoder.setSeamlessConnection(enabled))
    }

    // Fit Test
    func startFitTest() async {
        await sendFireAndForget(FitTestEncoder.startCheck())
    }

    // Debug / Diagnostics
    func requestDebugAllData() async {
        await sendFireAndForget(DebugEncoder.debugGetAllData())
    }

    func requestSerialNumber() async {
        await sendFireAndForget(DebugEncoder.debugSerialNumber())
    }

    func requestBuildInfo() async {
        await sendFireAndForget(DebugEncoder.debugBuildInfo())
    }

    func requestSku() async {
        await sendFireAndForget(DebugEncoder.debugSku())
    }

    func requestCradleSerialNumber() async {
        await sendFireAndForget(DebugEncoder.cradleSerialNumber())
    }

    func requestBatteryCycles() async {
        await sendFireAndForget(DebugEncoder.socBatteryCycle())
    }

    func requestBatteryType() async {
        await sendFireAndForget(DebugEncoder.batteryType())
    }
}

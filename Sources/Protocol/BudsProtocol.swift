// BudsProtocol.swift
// Protocol orchestrator — handles incoming message dispatch, outgoing command construction,
// and state synchronization. Sits between the Bluetooth layer and the UI.

import Foundation

/// Orchestrates the Samsung Galaxy Buds SPP protocol.
@MainActor
final class BudsProtocol {

    let deviceState: DeviceState
    private var commandQueue = CommandQueue()
    var onError: ((String) -> Void)?
    private var fitTimeout: Task<Void, Never>?
    let spec = BudsDeviceSpec()
    private var sendHandler: (([UInt8]) async -> Bool)?
    private var handshakeComplete = false
    private var sessionGeneration = 0
    private var profile: BudsConnectionProfile = .buds2Pro

    init(deviceState: DeviceState) {
        self.deviceState = deviceState
    }

    private var incomingBuffer: [UInt8] = []

    // MARK: - Lifecycle

    func start(profile: BudsConnectionProfile = .buds2Pro,
               sendHandler: @escaping ([UInt8]) async -> Bool) async {
        sessionGeneration += 1
        self.profile = profile
        self.sendHandler = sendHandler
        handshakeComplete = false
        incomingBuffer.removeAll()

        await commandQueue.start { message in
            ProtocolLogger.logOutgoing(message)
            let raw = message.encode()
            _ = await sendHandler(raw)
        }
        ProtocolLogger.log(.info, "Protocol layer started for \(spec.deviceBaseName)")
    }

    func stop() {
        sessionGeneration += 1
        deviceState.pendingCommands = []
        let oldQueue = commandQueue
        commandQueue = CommandQueue()
        Task { await oldQueue.stop() }
        sendHandler = nil
        fitTimeout?.cancel()
        deviceState.hasReceivedStatus = false
        deviceState.findMyActive = false
        deviceState.fitTestRunning = false
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
            guard !message.isFragment else {
                ProtocolLogger.log(.warning, "Ignoring unsupported fragmented message")
                continue
            }
            ProtocolLogger.logIncoming(message, rawBytes: message.encode())
            processMessage(message)
        }
    }

    private func processMessage(_ message: BudsMessage) {
        if !profile.hasControls {
            guard message.id == .extendedStatusUpdated || message.id == .statusUpdated else { return }
            do {
                let status = try BasicBudsStatusDecoder(
                    payload: message.payload, extended: message.id == .extendedStatusUpdated)
                status.apply(to: deviceState)
            } catch {
                ProtocolLogger.log(.warning, "Ignored truncated basic status: \(error)")
            }
            return
        }
        if message.id == .universalAcknowledgement, let raw = message.payload.first {
            let response = BudsMessage(id: .from(raw), type: .response, payload: Array(message.payload.dropFirst()), rawID: raw)
            applyAcknowledgedSetting(response)
            Task { await commandQueue.handleResponse(response) }
            return
        }
        if message.type == .response {
            Task { await commandQueue.handleResponse(message) }
        }
        switch message.id {
        // Status
        case .extendedStatusUpdated: handleExtendedStatusUpdated(message)
        case .statusUpdated:         handleStatusUpdated(message)
        case .connectionUpdated:     handleConnectionUpdated(message)
        case .versionInfo:           handleVersionInfo(message)
        case .versionInfoLong:       handleVersionInfoLong(message)

        // Noise control
        case .noiseControlsUpdate:
            handleNoiseControlsUpdate(message)
            // This notification is also used to confirm a mode change on some firmware.
            if let mode = message.payload.first {
                Task { await commandQueue.confirmNotification(.response(.noiseControls, payload: [mode])) }
            }
        case .ambientModeUpdated:    handleAmbientModeUpdated(message)

        // Touch
        case .touchUpdated:          handleTouchUpdated(message)

        // Mute
        case .muteEarbudStatusUpdated: handleMuteStatus(message)

        // Fit test
        case .checkFitResult:        handleFitTestResult(message)
        case .findMyEarbudsStart: deviceState.findMyActive = true
        case .findMyEarbudsStop:
            deviceState.findMyActive = false
            deviceState.findMyLeftMuted = false
            deviceState.findMyRightMuted = false

        // Debug responses
        case .debugSerialNumber, .debugBuildInfo, .debugGetVersion, .debugSku,
             .debugGetAllData, .cradleSerialNumber, .socBatteryCycle, .batteryType:
            handleDebugResponse(message)

        // Default
        default:
            if message.type == .response {
                ProtocolLogger.log(.info, "Command response: \(message.id)")
            } else {
                ProtocolLogger.log(.info, "Unhandled message: \(message.id) (\(message.payload.count) bytes)")
                if message.id != .unknown { sendAcknowledgement(for: message.id) }
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

        Task { await requestInitialState() }
    }

    private func handleStatusUpdated(_ message: BudsMessage) {
        if let decoder = try? StatusUpdateDecoder(payload: message.payload) {
            decoder.apply(to: deviceState)
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
        fitTimeout?.cancel()
        Task { await sendFireAndForget(.request(.checkFitOfEarbuds, payload: [0])) }
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
        guard profile.hasControls else { return }
        guard !handshakeComplete, sendHandler != nil, deviceState.connectionState.isConnected else { return }
        handshakeComplete = true
        ProtocolLogger.log(.info, "Sending Galaxy Buds2 Pro handshake & initial queries...")
        await sendFireAndForget(ManagerInfoEncoder.encode())
        await sendFireAndForget(UpdateTimeEncoder.encode())
        await sendFireAndForget(.request(.versionInfo))
        await sendFireAndForget(DebugEncoder.debugSerialNumber())
        handshakeComplete = true
    }

    private func requestInitialData() async {
        await sendFireAndForget(.request(.versionInfo))
        await sendFireAndForget(DebugEncoder.debugSerialNumber())
        await sendFireAndForget(UpdateTimeEncoder.encode())
    }

    // MARK: - Sending

    func sendCommand(
        _ message: BudsMessage,
        completion: ((Result<BudsMessage, BudsError>) -> Void)? = nil
    ) async {
        guard profile.hasControls else {
            onError?("Controls are not yet available for this Galaxy Buds model.")
            completion?(.failure(.notConnected))
            return
        }
        guard deviceState.connectionState.isConnected, deviceState.hasReceivedStatus else {
            onError?("Wait for the earbuds to connect and finish syncing.")
            completion?(.failure(.notConnected))
            return
        }
        guard !deviceState.pendingCommands.contains(message.rawID) else { return }
        deviceState.pendingCommands.insert(message.rawID)
        let generation = sessionGeneration
        await commandQueue.enqueue(message, maxRetries: 0) { [weak self] result in
            Task { @MainActor in
                guard let self, generation == self.sessionGeneration else { return }
                self.deviceState.pendingCommands.remove(message.rawID)
                completion?(result)
                if case .failure(let error) = result, error != .commandReplaced && error != .disconnected && error != .cancelled {
                    self.onError?("Setting was not confirmed: \(error.description). Reconnect and try again.")
                }
            }
        }
    }

    func sendFireAndForget(_ message: BudsMessage) async {
        guard profile.hasControls else { return }
        ProtocolLogger.logOutgoing(message)
        let raw = message.encode()
        if let handler = sendHandler, !(await handler(raw)) {
            onError?("Could not send to the earbuds. Check the Bluetooth connection.")
        }
    }

    private func sendAcknowledgement(for messageId: BudsMessageId) {
        Task {
            let ack = BudsMessage.ack(for: messageId)
            await sendFireAndForget(ack)
        }
    }

    func stopFitTest() async {
        fitTimeout?.cancel()
        deviceState.fitTestRunning = false
        await sendFireAndForget(.request(.checkFitOfEarbuds, payload: [0]))
    }

    private func applyAcknowledgedSetting(_ message: BudsMessage) {
        guard let value = message.payload.first else { return }
        let enabled = value == 1
        switch message.id {
        case .noiseControls:
            if let mode = NoiseControlMode(rawValue: Int(value)) {
                deviceState.noiseControlMode = mode
                deviceState.ancEnabled = mode == .anc
                deviceState.ambientEnabled = mode == .ambient
            }
        case .equalizer: deviceState.equalizerPreset = EqualizerPreset(rawValue: Int(value)) ?? .disabled
        case .ambientVolume: deviceState.ambientVolume = Int(value)
        case .extraHighAmbient: deviceState.extraHighAmbient = enabled
        case .setAncWithOneEarbud: deviceState.ancWithOneEarbud = enabled
        case .adjustSoundSync: deviceState.adjustSoundSync = enabled; deviceState.gameModeEnabled = enabled
        case .setSidetone: deviceState.sidetoneEnabled = enabled
        case .setDetectConversations: deviceState.detectConversations = enabled
        case .setDetectConversationsDuration: deviceState.detectConversationsDuration = Int(value)
        case .lockTouchpad:
            // The lock command uses 0 for locked and 1 for unlocked.
            deviceState.touchpadLocked = value == 0
            if message.payload.count >= 5 {
                let bits: [UInt8] = [3, 2, 1, 0, 4, 5]
                var flags: UInt8 = 0
                for index in 1..<min(message.payload.count, 7) where message.payload[index] == 1 {
                    flags |= 1 << bits[index - 1]
                }
                deviceState.touchEnabledFlags = flags
            }
        case .setHearingEnhancements: deviceState.stereoBalance = min(Int(value), 32)
        case .outsideDoubleTap: deviceState.doubleTapVolume = enabled
        case .setSeamlessConnection: deviceState.seamlessConnection = !enabled
        case .extraClearSoundCall: deviceState.extraClearCallSound = enabled
        case .customizeAmbientSound:
            guard message.payload.count >= 4 else { return }
            deviceState.customAmbientEnabled = enabled
            deviceState.customAmbientLeft = Int(message.payload[1])
            deviceState.customAmbientRight = Int(message.payload[2])
            deviceState.customAmbientTone = Int(message.payload[3])
        case .setTouchpadOption:
            guard message.payload.count >= 2 else { return }
            deviceState.touchLeftAction = TouchAction(rawValue: value) ?? .none
            deviceState.touchRightAction = TouchAction(rawValue: message.payload[1]) ?? .none
        case .muteEarbud:
            guard message.payload.count >= 2 else { return }
            deviceState.findMyLeftMuted = enabled
            deviceState.findMyRightMuted = message.payload[1] == 1
        default: break
        }
    }

    func setTapEnabled(bit: UInt8, enabled: Bool) async {
        guard bit < 6 else { return }
        let flags = enabled ? deviceState.touchEnabledFlags | (1 << bit) : deviceState.touchEnabledFlags & ~(1 << bit)
        await sendCommand(TouchpadEncoder.lock(deviceState.touchpadLocked, flags: flags, revision: deviceState.interfaceRevision))
    }

    func setStereoBalance(_ value: Int) async {
        await sendCommand(.request(.setHearingEnhancements, payload: [UInt8(max(0, min(value, 32)))]))
    }

    func setDoubleTapVolume(_ enabled: Bool) async {
        await sendCommand(.request(.outsideDoubleTap, payload: [enabled ? 1 : 0]))
    }

    func setCustomAmbient(enabled: Bool, left: Int, right: Int, tone: Int) async {
        await sendCommand(AmbientEncoder.customize(enabled: enabled, left: left, right: right, tone: tone,
                                                  maximum: deviceState.extraHighAmbient ? 4 : 2))
    }

    // MARK: - Public API

    // Noise Control
    func setNoiseControl(mode: NoiseControlMode) async {
        await sendCommand(NoiseControlEncoder.encode(mode: mode))
    }

    func setAncWithOneEarbud(_ enabled: Bool) async {
        await sendCommand(AncEncoder.setAncWithOneEarbud(enabled))
    }

    func setAdjustSoundSync(_ enabled: Bool) async {
        await sendCommand(AncEncoder.setAdjustSoundSync(enabled))
    }

    // Equalizer
    func setEqualizer(preset: EqualizerPreset) async {
        await sendCommand(EqualizerEncoder.encode(preset: preset))
    }

    // Ambient
    func setAmbientVolume(_ volume: Int) async {
        await sendCommand(AmbientEncoder.setVolume(volume, maximum: deviceState.extraHighAmbient ? 3 : 2))
    }

    func setExtraHighAmbient(_ enabled: Bool) async {
        await sendCommand(AmbientEncoder.setExtraHigh(enabled))
    }

    func customizeAmbient(left: UInt8, center: UInt8, right: UInt8) async {
        await sendCommand(AmbientEncoder.customizeAmbient(left: left, center: center, right: right))
    }

    func setNoiseReductionLevel(_ level: UInt8) async {
        await sendCommand(AmbientEncoder.setNoiseReductionLevel(level))
    }

    func setAmplifyAmbient(_ enabled: Bool) async {
        await sendCommand(AmbientEncoder.setAmplifyAmbient(enabled))
    }

    // Touch
    func setTouchpadLocked(_ locked: Bool) async {
        await sendCommand(TouchpadEncoder.lock(locked, flags: deviceState.touchEnabledFlags, revision: deviceState.interfaceRevision))
    }

    func setTouchActions(left: TouchAction, right: TouchAction) async {
        await sendCommand(TouchpadEncoder.setActions(left: left, right: right))
    }

    // Find My Earbuds
    // Start/stop are fire-and-forget: the earbuds confirm via findMyEarbudsStart/Stop
    // notifications rather than response frames, so response tracking would just
    // freeze the page and then fail with a spurious timeout.
    func startFindMyEarbuds() async {
        guard profile.hasControls else { return }
        guard deviceState.connectionState.isConnected, deviceState.hasReceivedStatus else {
            onError?("Wait for the earbuds to connect and finish syncing.")
            return
        }
        var message = FindMyEarbudsEncoder.start()
        if deviceState.isAnyBudWorn {
            // Revision >= 4 supports a quieter ring while a bud is being worn.
            guard spec.supports(.fmgRingWhileWearing, firmwareRevision: deviceState.interfaceRevision) else {
                onError?("Remove your earbuds before ringing them.")
                return
            }
            message = FindMyEarbudsEncoder.startOnWearing()
        }
        deviceState.findMyActive = true
        deviceState.findMyLeftMuted = false
        deviceState.findMyRightMuted = false
        await sendFireAndForget(message)
    }

    func stopFindMyEarbuds() async {
        deviceState.findMyActive = false
        deviceState.findMyLeftMuted = false
        deviceState.findMyRightMuted = false
        await sendFireAndForget(FindMyEarbudsEncoder.stop())
    }

    func muteFindMyEarbud(left: Bool, right: Bool) async {
        await sendCommand(FindMyEarbudsEncoder.mute(left: left, right: right))
    }

    // Audio Features
    func setSpatialAudio(_ enabled: Bool) async {
        await sendCommand(SpatialAudioEncoder.setEnabled(enabled))
    }

    func setGameMode(_ enabled: Bool) async {
        await sendCommand(GameModeEncoder.setEnabled(enabled))
    }

    func setAdaptiveVolume(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setAdaptiveVolume(enabled))
    }

    func setAdaptiveEq(_ enabled: Bool) async {
        await sendCommand(AdaptiveEqEncoder.setEnabled(enabled))
    }

    // Voice & Call
    func setDetectConversations(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setDetectConversations(enabled))
    }

    func setDetectConversationsDuration(_ duration: UInt8) async {
        await sendCommand(VoiceCallEncoder.setDetectConversationsDuration(duration))
    }

    func setSidetone(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setSidetone(enabled))
    }

    func setInBandRingtone(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setInBandRingtone(enabled))
    }

    func setVoiceNotification(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setVoiceNotification(enabled))
    }

    func setPauseMediaOnRemoval(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setPauseMediaOnRemoval(enabled))
    }

    func setExtraClearCallSound(_ enabled: Bool) async {
        await sendCommand(VoiceCallEncoder.setExtraClearCallSound(enabled))
    }

    // Device Management
    func resetDevice() async {
        await sendCommand(DeviceManagementEncoder.reset())
    }

    func rebootDevice() async {
        await sendCommand(DeviceManagementEncoder.reboot())
    }

    func powerOffDevice() async {
        await sendCommand(DeviceManagementEncoder.poweroff())
    }

    func renameDevice(name: String) async {
        onError?("Rename requires Galaxy Wearable on your phone; the alternate naming protocol is not implemented here.")
    }

    func setSeamlessConnection(_ enabled: Bool) async {
        await sendCommand(DeviceManagementEncoder.setSeamlessConnection(enabled))
    }

    // Fit Test
    func startFitTest() async {
        guard profile.hasControls else { return }
        guard deviceState.connectionState.isConnected, deviceState.hasReceivedStatus else {
            onError?("Wait for the earbuds to connect and finish syncing.")
            return
        }
        deviceState.fitTestResult = nil
        deviceState.fitTestRunning = true
        await sendFireAndForget(FitTestEncoder.startCheck())
        fitTimeout?.cancel()
        fitTimeout = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
            guard self.deviceState.fitTestRunning else { return }
            await self.stopFitTest()
            self.onError?("Fit test timed out. Wear both earbuds and try again.")
        }
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

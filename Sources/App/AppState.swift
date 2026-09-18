import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var deviceState = DeviceState()
    @Published var showBatteryInMenuBar = DevicePersistence.showBatteryInMenuBar {
        didSet { DevicePersistence.showBatteryInMenuBar = showBatteryInMenuBar }
    }
    @Published var autoReconnect = DevicePersistence.autoReconnect {
        didSet {
            DevicePersistence.autoReconnect = autoReconnect
            if !autoReconnect { stopReconnect() }
            else { manuallyDisconnected = false; scheduleReconnect() }
        }
    }
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var availablePairedDevices: [DiscoveredDevice] = []
    @Published var lastError: String?
    @Published var showDebugWindow = false
    var bluetoothNeedsOnboarding: Bool { availablePairedDevices.isEmpty }
    var hasPairedDevices: Bool { !availablePairedDevices.isEmpty && !deviceState.connectionState.isConnected }
    var canControl: Bool { deviceState.connectionState.isConnected && deviceState.hasReceivedStatus && deviceState.pendingCommands.isEmpty }

    private(set) var bluetoothManager: BluetoothManager!
    private var protocol_: BudsProtocol!
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var backoffTask: Task<Void, Never>?
    private var initialStateTask: Task<Void, Never>?
    private var backoffAttempt = 0
    private var manuallyDisconnected = false
    private var isSystemSleeping = false
    private var connectionGeneration = 0

    init() {
        bluetoothManager = BluetoothManager()
        protocol_ = BudsProtocol(deviceState: deviceState)
        // SwiftUI does not forward changes from nested ObservableObjects itself.
        deviceState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        bluetoothManager.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        protocol_.onError = { [weak self] error in self?.lastError = error }
        bluetoothManager.onDataReceived = { [weak self] data in self?.protocol_.processData(data) }
        bluetoothManager.onDeviceConnected = { [weak self] device in
            guard let self else { return }
            self.deviceState.deviceName = device.name ?? "Galaxy Buds2 Pro"
            if let address = device.addressString {
                self.deviceState.deviceAddress = address
                DevicePersistence.saveLastDevice(address: address, name: self.deviceState.deviceName)
            }
        }
        bluetoothManager.onConnectionStateChanged = { [weak self] state in self?.connectionChanged(state) }
        bluetoothManager.onBluetoothPoweredOn = { [weak self] in self?.scheduleReconnect() }
        bluetoothManager.onSystemDeviceConnected = { [weak self] _ in
            guard let self else { return }
            self.scanForDevices()
            self.scheduleReconnect()
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isSystemSleeping = true
                self.stopReconnect()
                self.bluetoothManager.disconnect()
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isSystemSleeping = false; self?.scheduleReconnect() }
        })
        scanForDevices()
        scheduleReconnect()
    }

    private func connectionChanged(_ state: ConnectionState) {
        deviceState.connectionState = state
        switch state {
        case .connected:
            stopReconnect()
            backoffAttempt = 0
            lastError = nil
            initialStateTask?.cancel()
            initialStateTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
                await self.protocol_.requestInitialState()
                do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                if !self.deviceState.hasReceivedStatus {
                    self.lastError = "Connected, but the earbuds have not sent their settings. Open the case, disconnect other managers, and reconnect."
                }
            }
        case .disconnected, .error:
            initialStateTask?.cancel()
            protocol_.stop()
            deviceState.reset()
            deviceState.connectionState = state
            if case .error(let message) = state { lastError = message }
            scheduleReconnect()
        default: break
        }
    }

    func scanForDevices() {
        discoveredDevices = bluetoothManager.findPairedGalaxyBuds()
        availablePairedDevices = discoveredDevices.filter(\.isGalaxyBuds)
        if availablePairedDevices.isEmpty {
            lastError = "Pair your Galaxy Buds2 Pro in System Settings → Bluetooth, then open their case."
        }
    }

    private func connect(_ device: DiscoveredDevice) async {
        guard !bluetoothManager.connectionState.isConnectingOrReconnecting else { return }
        if bluetoothManager.connectionState.isConnected {
            if device.id == deviceState.deviceAddress { return }
            bluetoothManager.disconnect()
        }
        stopReconnect()
        connectionGeneration += 1
        let generation = connectionGeneration
        protocol_.stop()
        deviceState.reset()
        deviceState.deviceName = device.name
        deviceState.deviceAddress = device.id
        lastError = nil
        await protocol_.start { [weak self] bytes in
            guard let self, generation == self.connectionGeneration else { return false }
            return await self.bluetoothManager.sendData(bytes)
        }
        guard generation == connectionGeneration, !isSystemSleeping else { return }
        bluetoothManager.connectToDevice(address: device.id)
    }

    func connectToDevice(_ device: DiscoveredDevice) async {
        manuallyDisconnected = false
        backoffAttempt = 0
        await connect(device)
    }

    func connectToAddress(_ address: String) async {
        scanForDevices()
        guard let device = availablePairedDevices.first(where: { $0.id == address }) else {
            lastError = "This device is no longer paired as a Buds2 Pro. Check Bluetooth Settings."
            return
        }
        await connectToDevice(device)
    }

    func connectToPairedDevice(_ device: DiscoveredDevice) async { await connectToDevice(device) }

    func disconnect() {
        manuallyDisconnected = true
        connectionGeneration += 1
        stopReconnect()
        initialStateTask?.cancel()
        DevicePersistence.recordDisconnect()
        bluetoothManager.disconnect()
    }

    func forgetDevice() {
        disconnect()
        DevicePersistence.clearLastDevice()
        scanForDevices()
    }

    func reconnect() async {
        manuallyDisconnected = false
        backoffAttempt = 0
        await connectPreferredDevice()
    }

    private func connectPreferredDevice() async {
        guard !isSystemSleeping else { return }
        scanForDevices()
        let preferred = availablePairedDevices.first { bluetoothManager.isDeviceConnected(address: $0.id) }
            ?? availablePairedDevices.first { $0.id == DevicePersistence.lastDeviceAddress }
            ?? availablePairedDevices.first
        if let preferred { await connect(preferred) }
        else { scheduleReconnect() }
    }

    private func scheduleReconnect() {
        guard autoReconnect, !manuallyDisconnected, !isSystemSleeping, bluetoothManager.isBluetoothAvailable,
              !bluetoothManager.connectionState.isConnected,
              !bluetoothManager.connectionState.isConnectingOrReconnecting,
              backoffTask == nil else { return }
        backoffAttempt += 1
        let delay = min(60.0, pow(2.0, Double(min(backoffAttempt - 1, 6))))
        backoffTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
            self.backoffTask = nil
            guard self.autoReconnect, !self.manuallyDisconnected, !self.isSystemSleeping else { return }
            await self.connectPreferredDevice()
        }
    }

    private func stopReconnect() {
        backoffTask?.cancel()
        backoffTask = nil
    }

    func setTapEnabled(bit: UInt8, enabled: Bool) async { await protocol_.setTapEnabled(bit: bit, enabled: enabled) }
    func setStereoBalance(_ value: Int) async { await protocol_.setStereoBalance(value) }
    func setDoubleTapVolume(_ enabled: Bool) async { await protocol_.setDoubleTapVolume(enabled) }
    func setSeamlessConnection(_ enabled: Bool) async { await protocol_.setSeamlessConnection(enabled) }
    func setCustomAmbient(enabled: Bool? = nil, left: Int? = nil, right: Int? = nil, tone: Int? = nil) async {
        await protocol_.setCustomAmbient(enabled: enabled ?? deviceState.customAmbientEnabled,
            left: left ?? deviceState.customAmbientLeft, right: right ?? deviceState.customAmbientRight,
            tone: tone ?? deviceState.customAmbientTone)
    }

    // MARK: - Noise Control

    func setNoiseControl(mode: NoiseControlMode) async {
        await protocol_.setNoiseControl(mode: mode)
    }
    func setAncWithOneEarbud(_ enabled: Bool) async {
        await protocol_.setAncWithOneEarbud(enabled)
    }
    func setAdjustSoundSync(_ enabled: Bool) async {
        await protocol_.setAdjustSoundSync(enabled)
    }

    // MARK: - Equalizer

    func setEqualizer(preset: EqualizerPreset) async {
        await protocol_.setEqualizer(preset: preset)
    }

    // MARK: - Ambient

    func setAmbientVolume(_ volume: Int) async {
        await protocol_.setAmbientVolume(volume)
    }
    func setExtraHighAmbient(_ enabled: Bool) async {
        await protocol_.setExtraHighAmbient(enabled)
    }
    func customizeAmbient(left: UInt8, center: UInt8, right: UInt8) async {
        await protocol_.customizeAmbient(left: left, center: center, right: right)
    }
    func setNoiseReductionLevel(_ level: UInt8) async { await protocol_.setNoiseReductionLevel(level) }
    func setAmplifyAmbient(_ enabled: Bool) async { await protocol_.setAmplifyAmbient(enabled) }

    // MARK: - Touch

    func setTouchpadLocked(_ locked: Bool) async {
        await protocol_.setTouchpadLocked(locked)
    }
    func setTouchActions(left: TouchAction, right: TouchAction) async {
        await protocol_.setTouchActions(left: left, right: right)
    }

    // MARK: - Find My Earbuds

    func startFindMyEarbuds() async { await protocol_.startFindMyEarbuds() }
    func stopFindMyEarbuds() async { await protocol_.stopFindMyEarbuds() }
    func muteFindMyEarbud(left: Bool, right: Bool) async {
        await protocol_.muteFindMyEarbud(left: left, right: right)
    }

    // MARK: - Audio Features

    func setSpatialAudio(_ enabled: Bool) async {
        await protocol_.setSpatialAudio(enabled)
    }
    func setGameMode(_ enabled: Bool) async {
        await protocol_.setAdjustSoundSync(enabled)
    }
    func setAdaptiveVolume(_ enabled: Bool) async {
        await protocol_.setAdaptiveVolume(enabled)
    }
    func setAdaptiveEq(_ enabled: Bool) async {
        await protocol_.setAdaptiveEq(enabled)
    }

    // MARK: - Voice & Call

    func setDetectConversations(_ enabled: Bool) async {
        await protocol_.setDetectConversations(enabled)
    }
    func setDetectConversationsDuration(_ duration: UInt8) async {
        await protocol_.setDetectConversationsDuration(duration)
    }
    func setSidetone(_ enabled: Bool) async {
        await protocol_.setSidetone(enabled)
    }
    func setInBandRingtone(_ enabled: Bool) async {
        await protocol_.setInBandRingtone(enabled)
    }
    func setVoiceNotification(_ enabled: Bool) async {
        await protocol_.setVoiceNotification(enabled)
    }
    func setPauseMediaOnRemoval(_ enabled: Bool) async {
        await protocol_.setPauseMediaOnRemoval(enabled)
    }
    func setExtraClearCallSound(_ enabled: Bool) async {
        await protocol_.setExtraClearCallSound(enabled)
    }

    // MARK: - Device Management

    func resetDevice() async { await protocol_.resetDevice() }
    func rebootDevice() async { await protocol_.rebootDevice() }
    func powerOffDevice() async { await protocol_.powerOffDevice() }
    func renameDevice(name: String) async { await protocol_.renameDevice(name: name) }

    // MARK: - Fit Test

    func startFitTest() async { await protocol_.startFitTest() }
    func stopFitTest() async { await protocol_.stopFitTest() }

    // MARK: - Debug / Diagnostics

    func requestDebugAllData() async { await protocol_.requestDebugAllData() }
    func requestSerialNumber() async { await protocol_.requestSerialNumber() }
    func requestBuildInfo() async { await protocol_.requestBuildInfo() }
    func requestSku() async { await protocol_.requestSku() }
    func requestCradleSerialNumber() async { await protocol_.requestCradleSerialNumber() }
    func requestBatteryCycles() async { await protocol_.requestBatteryCycles() }
    func requestBatteryType() async { await protocol_.requestBatteryType() }

    // MARK: - Log

    func exportProtocolLog() -> String { ProtocolLogger.exportText() }
}

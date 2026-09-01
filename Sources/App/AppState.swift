// AppState.swift
// Application state coordinator with auto-connect, onboarding, and state restoration.

import Foundation
import SwiftUI
import Combine

/// Central application state that coordinates all layers.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var deviceState = DeviceState()
    @Published var showBatteryInMenuBar = DevicePersistence.showBatteryInMenuBar
    @Published var autoReconnect = DevicePersistence.autoReconnect
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var lastError: String?
    @Published var showDebugWindow = false
    @Published var availablePairedDevices: [DiscoveredDevice] = []

    /// Whether the app needs Bluetooth onboarding (only for pairing, not for RFCOMM).
    var bluetoothNeedsOnboarding: Bool {
        // Only show onboarding if CoreBluetooth says Bluetooth is completely unavailable
        // AND we have no paired devices. RFCOMM doesn't need CoreBluetooth permission.
        return false
    }

    /// Whether we have paired devices but none connected yet.
    var hasPairedDevices: Bool {
        !availablePairedDevices.isEmpty && !deviceState.connectionState.isConnected
    }

    // MARK: - Managers

    private(set) var bluetoothManager: BluetoothManager!
    private var protocol_: BudsProtocol!

    // MARK: - Auto-Reconnect & System Observers

    private var backoffTask: Task<Void, Never>?
    private var backoffAttempt = 0
    private let maxBackoffAttempts = 15
    private var isInitialConnect = true
    private var isSystemSleeping = false

    // MARK: - Init

    init() {
        bluetoothManager = BluetoothManager()
        protocol_ = BudsProtocol(deviceState: deviceState)
        setupCallbacks()
        setupSystemObservers()

        showBatteryInMenuBar = DevicePersistence.showBatteryInMenuBar
        autoReconnect = DevicePersistence.autoReconnect

        // Auto-connect on launch
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms for CoreBluetooth init
            await autoConnectOnLaunch()
        }
    }

    // MARK: - System Observers (Sleep/Wake & Power)

    private func setupSystemObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                ProtocolLogger.log(.info, "⚡️ Mac woke from sleep — triggering instant Bluetooth scan/reconnect")
                self?.handleSystemWake()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                ProtocolLogger.log(.info, "💤 Mac preparing for sleep — pausing reconnection")
                self?.handleSystemSleep()
            }
        }
    }

    private func handleSystemWake() {
        isSystemSleeping = false
        stopReconnect()
        if autoReconnect && !deviceState.connectionState.isConnected {
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s for hardware wake
                await self.reconnect()
            }
        }
    }

    private func handleSystemSleep() {
        isSystemSleeping = true
        stopReconnect()
    }

    private func handleBluetoothPowerOn() {
        if !isSystemSleeping && autoReconnect && !deviceState.connectionState.isConnected {
            stopReconnect()
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self.reconnect()
            }
        }
    }

    // MARK: - Auto-Connect on Launch

    private func autoConnectOnLaunch() async {
        ProtocolLogger.log(.info, "=== Galaxy Buds2 Pro Manager starting ===")

        // Check CoreBluetooth permission (non-blocking — not required for RFCOMM)
        bluetoothManager.checkBluetoothPermission()

        // Find paired Galaxy Buds via IOBluetooth (this does NOT need CoreBluetooth)
        ProtocolLogger.log(.info, "Scanning for paired Galaxy Buds...")
        let allPaired = bluetoothManager.findPairedGalaxyBuds()
        let buds = allPaired.filter(\.isGalaxyBuds)

        availablePairedDevices = buds

        guard !buds.isEmpty else {
            ProtocolLogger.log(.info, "No paired Galaxy Buds found")
            lastError = "No paired Galaxy Buds found.\nPair your earbuds in System Settings > Bluetooth."
            return
        }

        ProtocolLogger.log(.info, "Found \(buds.count) paired Galaxy Buds: \(buds.map(\.name).joined(separator: ", "))")

        // 1. If any paired Galaxy Buds is already connected to macOS Bluetooth, connect to it immediately!
        let connectedBud = buds.first(where: {
            self.bluetoothManager.isDeviceConnected(address: $0.id)
        })

        if let active = connectedBud {
            ProtocolLogger.log(.info, "Found active connected Galaxy Buds: \(active.name) [\(active.id)] — connecting RFCOMM")
            DevicePersistence.saveLastDevice(address: active.id, name: active.name)
            await connectToDevice(active)
            return
        }

        // 2. Otherwise try last known device
        if let lastAddress = DevicePersistence.lastDeviceAddress,
           let lastDevice = buds.first(where: { $0.id == lastAddress }) {
            ProtocolLogger.log(.info, "Connecting to last known device: \(lastDevice.name)")
            await connectToDevice(lastDevice)
        } else if let firstBud = buds.first {
            ProtocolLogger.log(.info, "Connecting to first paired device: \(firstBud.name)")
            DevicePersistence.saveLastDevice(address: firstBud.id, name: firstBud.name)
            await connectToDevice(firstBud)
        }
    }

    // MARK: - Setup Callbacks

    private func setupCallbacks() {
        bluetoothManager.onDataReceived = { [weak self] data in
            Task { @MainActor in self?.protocol_.processData(data) }
        }

        bluetoothManager.onBluetoothPoweredOn = { [weak self] in
            Task { @MainActor in self?.handleBluetoothPowerOn() }
        }

        bluetoothManager.onSystemDeviceConnected = { [weak self] device in
            Task { @MainActor in
                guard let self = self, !self.deviceState.connectionState.isConnected else { return }
                let address = device.addressString ?? ""
                let name = device.name ?? "Galaxy Buds2 Pro"
                ProtocolLogger.log(.info, "🎧 Baseband device connected: \(name) [\(address)] — establishing RFCOMM")
                let discovered = DiscoveredDevice(id: address, name: name, rssi: 0, isGalaxyBuds: true)
                await self.connectToDevice(discovered)
            }
        }

        bluetoothManager.onConnectionStateChanged = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                self.deviceState.connectionState = state

                switch state {
                case .connected:
                    self.backoffAttempt = 0
                    self.isInitialConnect = false
                    self.stopReconnect()
                    self.lastError = nil

                    // Request initial state from device
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await self.protocol_.requestInitialState()
                    }

                case .error(let msg):
                    self.lastError = msg
                    ProtocolLogger.log(.error, "Connection error: \(msg)")
                    if self.autoReconnect && !self.isInitialConnect && !self.isSystemSleeping {
                        self.scheduleExponentialBackoffReconnect()
                    }

                case .disconnected:
                    self.protocol_.stop()
                    if self.autoReconnect && !self.isInitialConnect && !self.isSystemSleeping {
                        self.scheduleExponentialBackoffReconnect()
                    }

                default:
                    break
                }
            }
        }

        bluetoothManager.onDeviceDiscovered = { [weak self] device in
            Task { @MainActor in
                if !(self?.discoveredDevices.contains(where: { $0.id == device.id }) ?? true) {
                    self?.discoveredDevices.append(device)
                }
            }
        }
    }

    // MARK: - Connection

    func scanForDevices() {
        ProtocolLogger.log(.info, "Scanning for paired Galaxy Buds...")
        let buds = bluetoothManager.findPairedGalaxyBuds()
        availablePairedDevices = buds.filter(\.isGalaxyBuds)
        discoveredDevices = buds

        if availablePairedDevices.isEmpty {
            lastError = "No paired Galaxy Buds found.\nPair your earbuds in System Settings > Bluetooth first."
        }
    }

    func connectToDevice(_ device: DiscoveredDevice) async {
        stopReconnect()
        ProtocolLogger.log(.info, "Connecting to \(device.name) [\(device.id)]...")
        DevicePersistence.saveLastDevice(address: device.id, name: device.name)
        await protocol_.start { [weak self] data in self?.bluetoothManager.sendData(data) }
        bluetoothManager.connectToDevice(address: device.id)
    }

    func connectToAddress(_ address: String) async {
        stopReconnect()
        await protocol_.start { [weak self] data in self?.bluetoothManager.sendData(data) }
        bluetoothManager.connectToDevice(address: address)
    }

    func disconnect() {
        stopReconnect()
        isInitialConnect = false
        DevicePersistence.recordDisconnect()
        protocol_.stop()
        bluetoothManager.disconnect()
    }

    func reconnect() async {
        stopReconnect()
        ProtocolLogger.log(.info, "Reconnect triggered")

        if let address = DevicePersistence.lastDeviceAddress {
            ProtocolLogger.log(.info, "Reconnecting to last known device: \(address)")
            await connectToAddress(address)
            return
        }

        let buds = bluetoothManager.findPairedGalaxyBuds()
        availablePairedDevices = buds.filter(\.isGalaxyBuds)

        if let first = availablePairedDevices.first {
            ProtocolLogger.log(.info, "Found paired device: \(first.name)")
            await connectToDevice(first)
        } else {
            lastError = "No paired Galaxy Buds found.\nPair in System Settings > Bluetooth."
        }
    }

    func connectToPairedDevice(_ device: DiscoveredDevice) async {
        ProtocolLogger.log(.info, "User selected: \(device.name)")
        await connectToDevice(device)
    }

    // MARK: - Intelligent Exponential Backoff

    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 2s, 4s, 8s, 16s, 32s, max 60s
        let exponent = min(attempt - 1, 5)
        let delay = min(60.0, 2.0 * pow(2.0, Double(max(0, exponent))))
        return delay
    }

    private func scheduleExponentialBackoffReconnect() {
        backoffTask?.cancel()

        guard backoffAttempt < maxBackoffAttempts else {
            ProtocolLogger.log(.warning, "Auto-reconnect reached max attempts (\(maxBackoffAttempts)), waiting for system events")
            deviceState.connectionState = .disconnected
            lastError = "Could not reconnect automatically. Tap Connect to retry."
            return
        }

        backoffAttempt += 1
        let delay = calculateBackoffDelay(attempt: backoffAttempt)
        deviceState.connectionState = .reconnecting(attempt: backoffAttempt)
        ProtocolLogger.log(.info, "⏳ Scheduling reconnect attempt \(backoffAttempt)/\(maxBackoffAttempts) in \(String(format: "%.1f", delay))s")

        backoffTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self = self, !self.isSystemSleeping else { return }
            guard !self.deviceState.connectionState.isConnected else { return }

            ProtocolLogger.log(.info, "🔄 Executing backoff reconnect attempt \(self.backoffAttempt)")
            await self.reconnect()
        }
    }

    private func stopReconnect() {
        backoffTask?.cancel()
        backoffTask = nil
        backoffAttempt = 0
    }

    // MARK: - Noise Control

    func setNoiseControl(mode: NoiseControlMode) async {
        deviceState.noiseControlMode = mode
        deviceState.ancEnabled = (mode == .anc)
        deviceState.ambientEnabled = (mode == .ambient)
        await protocol_.setNoiseControl(mode: mode)
    }
    func setAncWithOneEarbud(_ enabled: Bool) async {
        deviceState.ancWithOneEarbud = enabled
        await protocol_.setAncWithOneEarbud(enabled)
    }
    func setAdjustSoundSync(_ enabled: Bool) async {
        deviceState.adjustSoundSync = enabled
        await protocol_.setAdjustSoundSync(enabled)
    }

    // MARK: - Equalizer

    func setEqualizer(preset: EqualizerPreset) async {
        deviceState.equalizerPreset = preset
        await protocol_.setEqualizer(preset: preset)
    }

    // MARK: - Ambient

    func setAmbientVolume(_ volume: Int) async {
        deviceState.ambientVolume = volume
        await protocol_.setAmbientVolume(volume)
    }
    func setExtraHighAmbient(_ enabled: Bool) async {
        deviceState.extraHighAmbient = enabled
        await protocol_.setExtraHighAmbient(enabled)
    }
    func customizeAmbient(left: UInt8, center: UInt8, right: UInt8) async {
        await protocol_.customizeAmbient(left: left, center: center, right: right)
    }
    func setNoiseReductionLevel(_ level: UInt8) async { await protocol_.setNoiseReductionLevel(level) }
    func setAmplifyAmbient(_ enabled: Bool) async { await protocol_.setAmplifyAmbient(enabled) }

    // MARK: - Touch

    func setTouchpadLocked(_ locked: Bool) async {
        deviceState.touchpadLocked = locked
        await protocol_.setTouchpadLocked(locked)
    }
    func setTouchActions(left: TouchAction, right: TouchAction) async {
        deviceState.touchLeftAction = left
        deviceState.touchRightAction = right
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
        deviceState.spatialAudioEnabled = enabled
        await protocol_.setSpatialAudio(enabled)
    }
    func setGameMode(_ enabled: Bool) async {
        deviceState.gameModeEnabled = enabled
        await protocol_.setGameMode(enabled)
    }
    func setAdaptiveVolume(_ enabled: Bool) async {
        deviceState.adaptiveVolumeEnabled = enabled
        await protocol_.setAdaptiveVolume(enabled)
    }
    func setAdaptiveEq(_ enabled: Bool) async {
        await protocol_.setAdaptiveEq(enabled)
    }

    // MARK: - Voice & Call

    func setDetectConversations(_ enabled: Bool) async {
        deviceState.detectConversations = enabled
        await protocol_.setDetectConversations(enabled)
    }
    func setDetectConversationsDuration(_ duration: UInt8) async {
        deviceState.detectConversationsDuration = Int(duration)
        await protocol_.setDetectConversationsDuration(duration)
    }
    func setSidetone(_ enabled: Bool) async {
        deviceState.sidetoneEnabled = enabled
        await protocol_.setSidetone(enabled)
    }
    func setInBandRingtone(_ enabled: Bool) async {
        deviceState.inBandRingtone = enabled
        await protocol_.setInBandRingtone(enabled)
    }
    func setVoiceNotification(_ enabled: Bool) async {
        deviceState.voiceNotificationEnabled = enabled
        await protocol_.setVoiceNotification(enabled)
    }
    func setPauseMediaOnRemoval(_ enabled: Bool) async {
        deviceState.pauseMediaOnRemoval = enabled
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

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var deviceState = DeviceState()
    @Published var showBatteryInMenuBar = DevicePersistence.showBatteryInMenuBar {
        didSet { DevicePersistence.showBatteryInMenuBar = showBatteryInMenuBar }
    }
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var availablePairedDevices: [DiscoveredDevice] = []
    @Published var lastError: String?
    @Published var showDebugWindow = false
    @Published private(set) var activeProfile: BudsConnectionProfile = .buds2Pro
    @Published private(set) var lastObservedBluetoothDeviceName: String?
    @Published private(set) var lastObservedWasGalaxyBuds: Bool?
    var bluetoothNeedsOnboarding: Bool { availablePairedDevices.isEmpty }
    var hasPairedDevices: Bool { !availablePairedDevices.isEmpty && !deviceState.connectionState.isConnected }
    var canControl: Bool { activeProfile.hasControls && deviceState.connectionState.isConnected && deviceState.hasReceivedStatus && deviceState.pendingCommands.isEmpty }

    private(set) var bluetoothManager: BluetoothManager!
    private var protocol_: BudsProtocol!
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var initialStateTask: Task<Void, Never>?
    private var attachRetryTask: Task<Void, Never>?
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
            self.deviceState.deviceName = device.name ?? "Galaxy Buds"
            if let address = device.addressString {
                self.deviceState.deviceAddress = address
                if self.activeProfile.hasControls {
                    DevicePersistence.saveLastDevice(address: address, name: self.deviceState.deviceName)
                }
            }
        }
        bluetoothManager.onConnectionStateChanged = { [weak self] state in self?.connectionChanged(state) }
        // The app never initiates Bluetooth connections on its own. It only
        // attaches to Galaxy Buds that macOS has already connected natively —
        // either right now (system connect notification) or before launch.
        bluetoothManager.onBluetoothPoweredOn = { [weak self] in self?.attachToSystemConnectedBuds() }
        bluetoothManager.onSystemDeviceConnected = { [weak self] device in
            guard let self else { return }
            // Classify every macOS connection event without querying or
            // opening a connection to unrelated Bluetooth devices.
            self.lastObservedBluetoothDeviceName = device.name
            self.lastObservedWasGalaxyBuds = device.isGalaxyBuds
            ProtocolLogger.log(.info, "Connected device \"\(device.name)\" is Galaxy Buds: \(device.isGalaxyBuds)")
            if device.isGalaxyBuds {
                self.scanForDevices()
            }
            // The connect notification can precede isConnected() becoming true.
            // Retry only local status checks; attach after macOS confirms the link.
            if device.isGalaxyBuds && device.profile.canConnect {
                self.attachToSystemConnectedBuds()
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isSystemSleeping = true
                self.bluetoothManager.disconnect()
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isSystemSleeping = false; self?.attachToSystemConnectedBuds() }
        })
        scanForDevices()
        attachToSystemConnectedBuds()
    }

    private func connectionChanged(_ state: ConnectionState) {
        deviceState.connectionState = state
        switch state {
        case .connected:
            lastError = nil
            initialStateTask?.cancel()
            initialStateTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
                await self.protocol_.requestInitialState()
                do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
                if !self.deviceState.hasReceivedStatus {
                    self.lastError = self.activeProfile.hasControls
                        ? "Connected, but the earbuds have not sent their settings. Open the case, disconnect other managers, and reconnect."
                        : "Connected, but no battery status was received from this model. Open the case and reconnect."
                }
            }
        case .disconnected, .error:
            initialStateTask?.cancel()
            protocol_.stop()
            deviceState.reset()
            deviceState.connectionState = state
            if case .error(let message) = state { lastError = message }
            // No automatic Bluetooth reconnect: stay idle until macOS
            // reconnects the earbuds or the user attaches to an existing link.
        default: break
        }
    }

    func scanForDevices() {
        discoveredDevices = bluetoothManager.findPairedGalaxyBuds()
        availablePairedDevices = discoveredDevices.filter(\.isGalaxyBuds)
        if lastObservedBluetoothDeviceName == nil,
           let connected = discoveredDevices.first(where: \.isSystemConnected) {
            lastObservedBluetoothDeviceName = connected.name
            lastObservedWasGalaxyBuds = connected.isGalaxyBuds
        }
        if availablePairedDevices.isEmpty {
            lastError = "Pair your Galaxy Buds in System Settings → Bluetooth, then open their case."
        }
    }

    private func connect(_ device: DiscoveredDevice) async {
        guard device.isGalaxyBuds else { return }
        guard device.profile.canConnect else {
            lastError = "This Galaxy Buds model is detected, but its configuration protocol is not supported yet."
            return
        }
        guard bluetoothManager.isDeviceConnected(address: device.id) else {
            lastError = "Connect \(device.name) in macOS Bluetooth settings first. This app will attach automatically."
            return
        }
        guard !bluetoothManager.connectionState.isConnectingOrReconnecting else { return }
        if bluetoothManager.connectionState.isConnected {
            if device.id == deviceState.deviceAddress { return }
            bluetoothManager.disconnect()
        }
        attachRetryTask?.cancel()
        attachRetryTask = nil
        connectionGeneration += 1
        let generation = connectionGeneration
        activeProfile = device.profile
        protocol_.stop()
        deviceState.reset()
        deviceState.deviceName = device.name
        deviceState.deviceAddress = device.id
        lastError = nil
        await protocol_.start(profile: device.profile) { [weak self] bytes in
            guard let self, generation == self.connectionGeneration else { return false }
            return await self.bluetoothManager.sendData(bytes)
        }
        guard generation == connectionGeneration, !isSystemSleeping else { return }
        bluetoothManager.connectToDevice(address: device.id, profile: device.profile)
    }

    func connectToDevice(_ device: DiscoveredDevice) async {
        await connect(device)
    }

    func connectToAddress(_ address: String) async {
        scanForDevices()
        guard let device = availablePairedDevices.first(where: { $0.id == address }) else {
            lastError = "This Galaxy Buds device is no longer paired. Check Bluetooth Settings."
            return
        }
        await connectToDevice(device)
    }

    func connectToPairedDevice(_ device: DiscoveredDevice) async { await connectToDevice(device) }

    func disconnect() {
        attachRetryTask?.cancel()
        attachRetryTask = nil
        connectionGeneration += 1
        initialStateTask?.cancel()
        bluetoothManager.disconnect()
    }

    func forgetDevice() {
        disconnect()
        DevicePersistence.clearLastDevice()
        scanForDevices()
    }

    func reconnect() async {
        await connectPreferredDevice()
    }

    private func connectPreferredDevice() async {
        guard !isSystemSleeping else { return }
        scanForDevices()
        let connectable = availablePairedDevices.filter { $0.canAttach }
        let preferred = connectable.first { $0.profile.hasControls && bluetoothManager.isDeviceConnected(address: $0.id) }
            ?? connectable.first { bluetoothManager.isDeviceConnected(address: $0.id) }
        if let preferred {
            await connect(preferred)
        } else {
            lastError = "Connect your Galaxy Buds in macOS Bluetooth settings first. This app will attach automatically."
        }
    }

    /// Attaches to Galaxy Buds that macOS has *already* connected natively.
    /// Never initiates a Bluetooth connection itself — if the earbuds are
    /// connected to another device (e.g. a phone) or were disconnected, the
    /// app stays idle until macOS connects them to this Mac again.
    ///
    /// A system connect event can arrive before the system link and service
    /// records are ready, so the attach is re-checked a few times over ~13s.
    /// This is bounded and strictly event-driven; it never loops forever.
    private func attachToSystemConnectedBuds() {
        attachRetryTask?.cancel()
        attachRetryTask = Task { @MainActor in
            for delay in [0.0, 1.5, 4.0, 8.0] {
                if delay > 0 {
                    do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                if self.tryAttachToSystemConnectedBuds() { return }
            }
        }
    }

    /// Returns true when the app is attached (or attaching) to the earbuds.
    @discardableResult
    private func tryAttachToSystemConnectedBuds() -> Bool {
        guard !isSystemSleeping, !bluetoothManager.connectionState.isConnected else {
            return bluetoothManager.connectionState.isConnected
        }
        if bluetoothManager.connectionState.isConnectingOrReconnecting { return true }
        scanForDevices()
        let connected = availablePairedDevices.first { $0.canAttach && $0.profile.hasControls && bluetoothManager.isDeviceConnected(address: $0.id) }
            ?? availablePairedDevices.first { $0.canAttach && bluetoothManager.isDeviceConnected(address: $0.id) }
        guard let connected else {
            return false
        }
        ProtocolLogger.log(.info, "macOS reports \"\(connected.name)\" connected — attaching passively")
        Task { @MainActor in await self.connect(connected) }
        return true
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

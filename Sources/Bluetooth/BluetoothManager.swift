// BluetoothManager.swift
// Bluetooth discovery and RFCOMM connection for Samsung Galaxy Buds on macOS.
//
// Uses IOBluetooth for paired device lookup and RFCOMM/SPP data exchange.
// CoreBluetooth is only used for optional BLE scanning — it is NOT required
// for RFCOMM connection to already-paired devices.

import Foundation
import CoreBluetooth
import CoreAudio
@preconcurrency import IOBluetooth

/// CoreAudio only publishes a Bluetooth audio endpoint while macOS has the
/// device connected. Its UID begins with the same address as IOBluetooth's
/// paired-device record (for example, AA-BB-CC-DD-EE-FF:output).
enum SystemBluetoothConnection {
    static func normalizedAddress(_ value: String) -> String {
        value.uppercased().filter { $0.isHexDigit }
    }

    static func addressFromAudioUID(_ uid: String) -> String? {
        let rawAddress = uid.components(separatedBy: ":").first ?? ""
        let address = normalizedAddress(rawAddress)
        return address.count == 12 ? address : nil
    }

    static func connectedAudioAddresses() -> Set<String> {
        var property = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioDeviceID>.size else {
            return []
        }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard devices.withUnsafeMutableBytes({ bytes in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, bytes.baseAddress!)
        }) == noErr else { return [] }

        var addresses = Set<String>()
        for device in devices {
            var transportProperty = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &transportProperty, 0, nil, &transportSize, &transport) == noErr,
                  transport == kAudioDeviceTransportTypeBluetooth else { continue }

            var uidProperty = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var uid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(device, &uidProperty, 0, nil, &uidSize, &uid) == noErr,
                  let uid else { continue }
            if let address = addressFromAudioUID(uid.takeUnretainedValue() as String) {
                addresses.insert(address)
            }
        }
        return addresses
    }

    static func isConnected(_ device: IOBluetoothDevice, audioAddresses: Set<String>? = nil) -> Bool {
        if device.isConnected() { return true }
        guard let address = device.addressString else { return false }
        return (audioAddresses ?? connectedAudioAddresses()).contains(normalizedAddress(address))
    }
}

/// Connection behavior is chosen before opening the Samsung service. Other
/// models only use the common battery fields; SM-R510 retains its full path.
enum BudsConnectionProfile: Equatable {
    case buds2Pro
    case basicStandardSPP
    case basicNewSPP
    case unsupported

    var canConnect: Bool { self != .unsupported }
    var hasControls: Bool { self == .buds2Pro }
    var serviceUUID: String {
        self == .basicStandardSPP ? BudsConstants.sppUuid : BudsConstants.sppNewUuid
    }

    static func identify(name: String, rememberedAddress: Bool = false) -> Self {
        if DiscoveredDevice.isBuds2ProName(name) || rememberedAddress { return .buds2Pro }
        let compact = name.lowercased().filter { !$0.isWhitespace }
        if ["budsplus", "buds+", "budslive", "budspro", "sm-r175", "sm-r180", "sm-r190"].contains(where: compact.contains) {
            return .basicStandardSPP
        }
        if ["buds2", "budsfe", "buds3", "sm-r177", "sm-r400", "sm-r630"].contains(where: compact.contains) {
            return .basicNewSPP
        }
        return .unsupported
    }
}

// MARK: - Bluetooth Device

struct DiscoveredDevice: Identifiable {
    let id: String  // MAC address
    let name: String
    let rssi: Int
    let isGalaxyBuds: Bool
    let isSystemConnected: Bool

    var profile: BudsConnectionProfile {
        BudsConnectionProfile.identify(name: name, rememberedAddress: id == DevicePersistence.lastDeviceAddress)
    }

    var canAttach: Bool { isGalaxyBuds && isSystemConnected && profile.canConnect }

    static func isGalaxyBudsName(_ name: String) -> Bool {
        if isBuds2ProName(name) { return true }
        let lower = name.lowercased()
        let compact = lower.replacingOccurrences(of: " ", with: "")
        return lower.hasPrefix("galaxy buds") || lower.hasPrefix("samsung galaxy buds")
            || BudsModel.allCases.contains { compact.contains($0.rawValue.lowercased()) }
    }

    static func isBuds2ProName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let compact = lower.replacingOccurrences(of: " ", with: "")
        return compact.contains("buds2pro") || lower.contains("sm-r510")
    }
}

// MARK: - Bluetooth Manager

@MainActor
final class BluetoothManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isBluetoothAvailable = false
    @Published var bluetoothPermissionGranted = false
    @Published var statusMessage: String = ""

    // MARK: - CoreBluetooth (optional, for BLE scanning only)

    private var centralManager: CBCentralManager?

    // MARK: - IOBluetooth (RFCOMM)

    private var rfcommChannel: IOBluetoothRFCOMMChannel?
    private var connectedDevice: IOBluetoothDevice?
    private let rfcommQueue = DispatchQueue(label: "com.galaxybuds.rfcomm", qos: .userInitiated)
    private var isConnecting = false
    private var cancelRequested = false
    private var attemptGeneration = 0
    private var targetProfile: BudsConnectionProfile = .buds2Pro

    // MARK: - Callbacks

    var onDataReceived: (([UInt8]) -> Void)?
    var onConnectionStateChanged: ((ConnectionState) -> Void)?
    var onDeviceDiscovered: ((DiscoveredDevice) -> Void)?
    var onBluetoothPoweredOn: (() -> Void)?
    var onSystemDeviceConnected: ((DiscoveredDevice) -> Void)?
    var onDeviceConnected: ((IOBluetoothDevice) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?

    // MARK: - Lifecycle

    override init() {
        super.init()

        // Initialize CoreBluetooth in the background for permission check.
        // This does NOT block RFCOMM — it's only used for optional BLE scanning.
        let delegate = CBDelegate()
        delegate.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleBluetoothState(state)
            }
        }
        centralManager = CBCentralManager(delegate: delegate, queue: nil)
        cbDelegate = delegate

        setupConnectNotification()
        ProtocolLogger.log(.info, "BluetoothManager initialized with connect notification observers")
    }

    private func setupConnectNotification() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleDeviceConnectedNotification(_:device:))
        )
    }

    @objc private func handleDeviceConnectedNotification(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        let cachedName = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice])?
            .first(where: { $0.addressString == address })?.name
        let rememberedName = address == DevicePersistence.lastDeviceAddress ? DevicePersistence.lastDeviceName : nil
        let name = device.name ?? cachedName ?? rememberedName ?? "Unknown Bluetooth device"
        Task { @MainActor in
            ProtocolLogger.log(.info, "System Bluetooth device connected: \"\(name)\" [\(address)]")
            guard !address.isEmpty else { return }
            let isBuds = DiscoveredDevice.isGalaxyBudsName(name) || address == DevicePersistence.lastDeviceAddress
            let connected = SystemBluetoothConnection.isConnected(device)
            let discovered = DiscoveredDevice(id: address, name: name,
                rssi: device.isConnected() ? Int(device.rawRSSI()) : 0,
                isGalaxyBuds: isBuds, isSystemConnected: connected)
            self.onSystemDeviceConnected?(discovered)
        }
    }

    deinit {
        connectNotification?.unregister()
    }

    private var cbDelegate: CBDelegate?

    // MARK: - Permission Check (non-blocking)

    func checkBluetoothPermission() {
        guard let central = centralManager else { return }

        switch central.authorization {
        case .allowedAlways:
            bluetoothPermissionGranted = true
            ProtocolLogger.log(.info, "Bluetooth permission: granted")
        case .notDetermined:
            // Will be determined once CBCentralManager finishes initializing
            ProtocolLogger.log(.info, "Bluetooth permission: waiting for CBCentralManager...")
        case .denied, .restricted:
            ProtocolLogger.log(.warning, "Bluetooth permission denied (not needed for RFCOMM)")
        @unknown default:
            break
        }

        // Also check if CBCentralManager is powered on
        if central.state == .poweredOn {
            bluetoothPermissionGranted = true
        }
    }

    private func handleBluetoothState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            isBluetoothAvailable = true
            bluetoothPermissionGranted = true
            ProtocolLogger.log(.info, "Bluetooth powered on — CoreBluetooth ready")
            onBluetoothPoweredOn?()
        case .poweredOff:
            isBluetoothAvailable = false
            disconnect()
            setStatus("Bluetooth is off. Turn it on in System Settings.")
        case .unauthorized:
            isBluetoothAvailable = false
            bluetoothPermissionGranted = false
            setStatus("Allow Bluetooth access in System Settings → Privacy & Security → Bluetooth.")
        case .unsupported:
            ProtocolLogger.log(.warning, "CoreBluetooth unsupported (not needed for RFCOMM)")
        case .resetting:
            isBluetoothAvailable = false
            disconnect()
            ProtocolLogger.log(.info, "CoreBluetooth resetting...")
        case .unknown:
            ProtocolLogger.log(.info, "CoreBluetooth state: unknown (still initializing)")
        @unknown default:
            break
        }
    }

    // MARK: - Paired Device Discovery (IOBluetooth)

    func findPairedGalaxyBuds() -> [DiscoveredDevice] {
        ProtocolLogger.log(.info, "Searching for paired Galaxy Buds via IOBluetooth...")

        let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        let connectedAudioAddresses = SystemBluetoothConnection.connectedAudioAddresses()
        var results: [DiscoveredDevice] = []
        var seenAddresses: Set<String> = []

        for device in pairedDevices {
            guard let name = device.name, !name.isEmpty else { continue }
            guard let address = device.addressString else { continue }
            guard !seenAddresses.contains(address) else { continue }
            seenAddresses.insert(address)

            let isBuds = DiscoveredDevice.isGalaxyBudsName(name) || address == DevicePersistence.lastDeviceAddress
            let connected = SystemBluetoothConnection.isConnected(device, audioAddresses: connectedAudioAddresses)
            let rssi = device.isConnected() ? Int(device.rawRSSI()) : 0

            if isBuds {
                ProtocolLogger.log(.info, "  → Galaxy Buds: \"\(name)\" [\(address)] connected=\(connected)")
            }

            let discovered = DiscoveredDevice(
                id: address,
                name: name,
                rssi: rssi,
                isGalaxyBuds: isBuds,
                isSystemConnected: connected
            )
            results.append(discovered)
            onDeviceDiscovered?(discovered)
        }

        // Sort so Galaxy Buds and connected devices appear first
        results.sort { a, b in
            if a.isGalaxyBuds != b.isGalaxyBuds {
                return a.isGalaxyBuds && !b.isGalaxyBuds
            }
            return a.name < b.name
        }

        discoveredDevices = results
        let buds = results.filter(\.isGalaxyBuds)
        ProtocolLogger.log(.info, "Found \(buds.count) Galaxy Buds among \(results.count) paired devices")
        return results
    }

    func findPairedGalaxyBudsDevice() -> DiscoveredDevice? {
        return findPairedGalaxyBuds().first(where: \.canAttach)
    }

    // MARK: - Connection via RFCOMM (Non-blocking background queue)

    func connectToDevice(address: String, profile: BudsConnectionProfile) {
        guard profile.canConnect else {
            rejectConnection("This Galaxy Buds model does not have a supported configuration protocol yet.")
            return
        }
        guard isBluetoothAvailable else {
            updateState(.error(statusMessage.isEmpty ? "Bluetooth is unavailable. Turn it on and allow access in System Settings." : statusMessage))
            return
        }
        if isConnecting {
            ProtocolLogger.log(.info, "Connection attempt already in progress for \(address), skipping duplicate request")
            return
        }

        if connectionState.isConnected, let current = connectedDevice, current.addressString == address {
            ProtocolLogger.log(.info, "Already connected to \(address)")
            return
        }

        guard let device = IOBluetoothDevice(addressString: address) else {
            let msg = "Device not found: \(address). Ensure it's paired in System Settings."
            isConnecting = false
            updateState(.disconnected)
            setStatus(msg)
            ProtocolLogger.log(.warning, "IOBluetoothDevice(addressString:) returned nil for \(address)")
            return
        }
        let cachedName = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice])?
            .first(where: { $0.addressString == address })?.name
        let isBuds = DiscoveredDevice.isGalaxyBudsName(device.name ?? cachedName ?? "")
            || address == DevicePersistence.lastDeviceAddress
        guard isBuds else {
            rejectConnection("The connected Bluetooth device is not recognized as Galaxy Buds.")
            return
        }
        let identifiedProfile = BudsConnectionProfile.identify(
            name: device.name ?? cachedName ?? "",
            rememberedAddress: address == DevicePersistence.lastDeviceAddress)
        guard profile == identifiedProfile else {
            rejectConnection("Galaxy Buds model changed. Scan again before attaching.")
            return
        }

        // SDP and RFCOMM may create a baseband link themselves. Never call
        // either when macOS does not already have this device connected.
        guard isDeviceConnected(address: address) else {
            rejectConnection("Connect the earbuds in macOS Bluetooth settings first.")
            return
        }

        closeCurrentChannel()
        attemptGeneration += 1
        targetProfile = profile
        let deviceName = device.name ?? "Galaxy Buds"
        connectedDevice = device

        if !device.isPaired() {
            let msg = "Device not paired. Please pair in System Settings > Bluetooth first."
            isConnecting = false
            updateState(.disconnected)
            setStatus(msg)
            ProtocolLogger.log(.warning, "Device not paired: \(address)")
            return
        }

        isConnecting = true
        cancelRequested = false
        updateState(.connecting)
        setStatus("Connecting to \(deviceName)...")
        ProtocolLogger.log(.info, "=== Connecting RFCOMM to \(deviceName) [\(address)] ===")

        targetDevice = device

        // Resolve Samsung's configuration service, rather than probing audio channels.
        if let channel = serviceChannel(device) {
            candidateChannels = [channel]
            currentChannelIndex = 0
            tryNextChannel()
        } else {
            guard isDeviceConnected(address: address) else {
                failConnection("The macOS Bluetooth connection was lost before service discovery.")
                return
            }
            setStatus("Discovering the Galaxy Buds configuration service…")
            let result = device.performSDPQuery(self)
            guard result == kIOReturnSuccess else { failConnection("Bluetooth service discovery failed (\(result))."); return }
            let generation = attemptGeneration
            channelOpenTimeoutTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
                guard generation == self.attemptGeneration, self.isConnecting else { return }
                self.failConnection("Service discovery timed out. Open the case and connect the earbuds in Bluetooth Settings.")
            }
        }
    }

    private func serviceChannel(_ device: IOBluetoothDevice) -> UInt8? {
        var uuid = UUID(uuidString: targetProfile.serviceUUID)!.uuid
        let serviceUUID = withUnsafeBytes(of: &uuid) { IOBluetoothSDPUUID(bytes: $0.baseAddress, length: 16) }
        guard let service = device.getServiceRecord(for: serviceUUID) else { return nil }
        var channel: BluetoothRFCOMMChannelID = 0
        guard service.getRFCOMMChannelID(&channel) == kIOReturnSuccess, channel > 0 else { return nil }
        return channel
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard isConnecting, !cancelRequested, let device, device == targetDevice, rfcommChannel == nil else { return }
        channelOpenTimeoutTask?.cancel()
        guard isDeviceConnected(address: device.addressString ?? "") else {
            failConnection("The macOS Bluetooth connection was lost during service discovery.")
            return
        }
        guard status == kIOReturnSuccess, let channel = serviceChannel(device) else {
            failConnection("The Galaxy Buds configuration service is unavailable. Connect the earbuds to this Mac and try again.")
            return
        }
        candidateChannels = [channel]
        currentChannelIndex = 0
        tryNextChannel()
    }

    private func closeCurrentChannel() {
        let channel = rfcommChannel
        rfcommChannel = nil
        channel?.setDelegate(nil)
        channel?.close()
    }

    private func failConnection(_ message: String) {
        channelOpenTimeoutTask?.cancel()
        isConnecting = false
        closeCurrentChannel()
        targetDevice = nil
        connectedDevice = nil
        setStatus(message)
        updateState(.error(message))
    }

    private func rejectConnection(_ message: String) {
        setStatus(message)
        updateState(.error(message))
    }

    private var candidateChannels: [UInt8] = []
    private var currentChannelIndex: Int = 0
    private var targetDevice: IOBluetoothDevice?
    private var channelOpenTimeoutTask: Task<Void, Never>?

    private func tryNextChannel() {
        channelOpenTimeoutTask?.cancel()
        guard isConnecting, !cancelRequested, let device = targetDevice else { return }
        guard isDeviceConnected(address: device.addressString ?? "") else {
            failConnection("The macOS Bluetooth connection was lost before opening the settings channel.")
            return
        }

        guard currentChannelIndex < candidateChannels.count else {
            failConnection("Could not open the configuration channel. Open the case and ensure the earbuds are connected to this Mac.")
            ProtocolLogger.log(.warning, "All candidate RFCOMM channels exhausted for \(device.name ?? "device")")
            return
        }

        closeCurrentChannel()
        let cid = candidateChannels[currentChannelIndex]
        currentChannelIndex += 1
        ProtocolLogger.log(.info, "Opening RFCOMM channel \(cid) for \(device.name ?? "Galaxy Buds")...")

        let res = device.openRFCOMMChannelAsync(&self.rfcommChannel, withChannelID: cid, delegate: self)
        if res != kIOReturnSuccess {
            ProtocolLogger.log(.verbose, "openRFCOMMChannelAsync(\(cid)) returned: \(res)")
            tryNextChannel()
            return
        }

        let generation = attemptGeneration
        channelOpenTimeoutTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
            if generation == self.attemptGeneration && self.isConnecting && self.connectionState != .connected {
                ProtocolLogger.log(.verbose, "Channel \(cid) attempt timed out, advancing...")
                self.tryNextChannel()
            }
        }
    }

    func isDeviceConnected(address: String) -> Bool {
        if let dev = IOBluetoothDevice(addressString: address) {
            return SystemBluetoothConnection.isConnected(dev)
        }
        return false
    }

    private func setupChannel(_ channel: IOBluetoothRFCOMMChannel, device: IOBluetoothDevice, deviceName: String) {
        channelOpenTimeoutTask?.cancel()
        channelOpenTimeoutTask = nil
        rfcommChannel = channel
        connectedDevice = device
        isConnecting = false

        updateState(.connected)
        setStatus("Connected to \(deviceName)")
        ProtocolLogger.log(.info, "✓ Connected to \(deviceName) on RFCOMM channel \(channel.getID())")
        onDeviceConnected?(device)
    }

    func sendData(_ data: [UInt8]) async -> Bool {
        guard let channel = rfcommChannel, channel.isOpen(), !data.isEmpty,
              data.count <= Int(UInt16.max) else { return false }
        let generation = attemptGeneration
        let result: IOReturn = await withCheckedContinuation { continuation in
            rfcommQueue.async {
                var bytes = data
                let result = bytes.withUnsafeMutableBufferPointer {
                    channel.writeSync($0.baseAddress!, length: UInt16($0.count))
                }
                continuation.resume(returning: result)
            }
        }
        guard generation == attemptGeneration else { return false }
        if result != kIOReturnSuccess {
            failConnection("Could not send the setting to your earbuds (Bluetooth error \(result)).")
            return false
        }
        return true
    }

    // MARK: - Disconnection

    func disconnect() {
        channelOpenTimeoutTask?.cancel()
        channelOpenTimeoutTask = nil
        cancelRequested = true
        isConnecting = false
        updateState(.disconnecting)
        setStatus("Disconnecting...")

        attemptGeneration += 1
        closeCurrentChannel()
        connectedDevice = nil
        targetDevice = nil
        updateState(.disconnected)
        setStatus("Disconnected")
    }

    // MARK: - Helpers

    private func updateState(_ newState: ConnectionState) {
        connectionState = newState
        onConnectionStateChanged?(newState)
    }

    private func setStatus(_ message: String) {
        statusMessage = message
    }
}

// MARK: - CBCentralManager Delegate

private class CBDelegate: NSObject, CBCentralManagerDelegate {
    var onStateChange: ((CBManagerState) -> Void)?
    var onDiscover: ((CBPeripheral, [String: Any], NSNumber) -> Void)?

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onStateChange?(central.state)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        onDiscover?(peripheral, advertisementData, RSSI)
    }
}

// MARK: - IOBluetoothRFCOMMChannelDelegate

extension BluetoothManager: IOBluetoothRFCOMMChannelDelegate {

    nonisolated func rfcommChannelOpenComplete(
        _ channel: IOBluetoothRFCOMMChannel!,
        status error: IOReturn
    ) {
        Task { @MainActor in
            guard let channel, channel === self.rfcommChannel, self.isConnecting, !self.cancelRequested else { return }
            if error == kIOReturnSuccess {
                let ch = channel
                guard let dev = ch.getDevice() ?? self.targetDevice ?? self.connectedDevice else { return }
                self.setupChannel(ch, device: dev, deviceName: dev.name ?? "Galaxy Buds")
            } else {
                if self.isConnecting {
                    self.tryNextChannel()
                }
            }
        }
    }

    nonisolated func rfcommChannelData(
        _ channel: IOBluetoothRFCOMMChannel!,
        data dataPointer: UnsafeMutableRawPointer!,
        length dataLength: Int
    ) {
        guard let ptr = dataPointer, dataLength > 0 else { return }

        let bytes = Array(UnsafeBufferPointer(
            start: ptr.assumingMemoryBound(to: UInt8.self),
            count: dataLength
        ))

        Task { @MainActor in
            guard let channel, channel === self.rfcommChannel, !self.cancelRequested else { return }
            onDataReceived?(bytes)
        }
    }

    nonisolated func rfcommChannelClosed(_ channel: IOBluetoothRFCOMMChannel!) {
        Task { @MainActor in
            guard let channel, channel === self.rfcommChannel else { return }
            self.channelOpenTimeoutTask?.cancel()
            self.rfcommChannel = nil
            self.connectedDevice = nil
            self.targetDevice = nil
            self.isConnecting = false
            ProtocolLogger.log(.warning, "RFCOMM channel closed unexpectedly")
            self.updateState(.disconnected)
            self.setStatus("Connection lost")
        }
    }
}

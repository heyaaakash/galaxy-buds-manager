// BluetoothManager.swift
// Bluetooth discovery and RFCOMM connection for Samsung Galaxy Buds2 Pro on macOS.
//
// Uses IOBluetooth for paired device lookup and RFCOMM/SPP data exchange.
// CoreBluetooth is only used for optional BLE scanning — it is NOT required
// for RFCOMM connection to already-paired devices.

import Foundation
import CoreBluetooth
@preconcurrency import IOBluetooth

// MARK: - Bluetooth Device

struct DiscoveredDevice: Identifiable {
    let id: String  // MAC address
    let name: String
    let rssi: Int
    let isGalaxyBuds: Bool

    static func isGalaxyBudsName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("galaxy bud") ||
               lower.contains("buds") ||
               lower.contains("sm-r510") ||
               lower.contains("sm-r51")
    }
}

// MARK: - Bluetooth Manager

@MainActor
final class BluetoothManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning = false
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var bluetoothPermissionGranted = false
    @Published var statusMessage: String = ""

    // MARK: - CoreBluetooth (optional, for BLE scanning only)

    private var centralManager: CBCentralManager?

    // MARK: - IOBluetooth (RFCOMM)

    private var rfcommChannel: IOBluetoothRFCOMMChannel?
    private var connectedDevice: IOBluetoothDevice?
    private let rfcommQueue = DispatchQueue(label: "com.galaxybuds.rfcomm", qos: .userInitiated)
    private var isConnecting = false
    nonisolated(unsafe) private var cancelRequested = false

    // MARK: - Callbacks

    var onDataReceived: (([UInt8]) -> Void)?
    var onConnectionStateChanged: ((ConnectionState) -> Void)?
    var onDeviceDiscovered: ((DiscoveredDevice) -> Void)?
    var onBluetoothPoweredOn: (() -> Void)?
    var onSystemDeviceConnected: ((IOBluetoothDevice) -> Void)?
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
        let name = device.name ?? ""
        let address = device.addressString ?? ""
        Task { @MainActor in
            ProtocolLogger.log(.info, "System Bluetooth device connected: \"\(name)\" [\(address)]")
            if DiscoveredDevice.isGalaxyBudsName(name) || address == DevicePersistence.lastDeviceAddress {
                self.onSystemDeviceConnected?(device)
            }
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
            bluetoothPermissionGranted = true
            ProtocolLogger.log(.info, "Bluetooth powered on — CoreBluetooth ready")
            onBluetoothPoweredOn?()
        case .poweredOff:
            ProtocolLogger.log(.warning, "Bluetooth powered off (RFCOMM may still work)")
        case .unauthorized:
            ProtocolLogger.log(.warning, "CoreBluetooth unauthorized (not needed for RFCOMM)")
        case .unsupported:
            ProtocolLogger.log(.warning, "CoreBluetooth unsupported (not needed for RFCOMM)")
        case .resetting:
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
        var results: [DiscoveredDevice] = []
        var seenAddresses: Set<String> = []

        for device in pairedDevices {
            guard let name = device.name, !name.isEmpty else { continue }
            let address = device.addressString ?? "unknown"
            guard !seenAddresses.contains(address) else { continue }
            seenAddresses.insert(address)

            let isBuds = DiscoveredDevice.isGalaxyBudsName(name)
            let connected = device.isConnected()
            let rssi = connected ? Int(device.rawRSSI()) : 0

            if isBuds {
                ProtocolLogger.log(.info, "  → Galaxy Buds: \"\(name)\" [\(address)] connected=\(connected)")
            }

            let discovered = DiscoveredDevice(
                id: address,
                name: name,
                rssi: rssi,
                isGalaxyBuds: isBuds
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
        return findPairedGalaxyBuds().first(where: { $0.isGalaxyBuds })
    }

    // MARK: - Connection via RFCOMM (Non-blocking background queue)

    func connectToDevice(address: String) {
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

        // Gather candidate SDP channels from device services if available
        var sdpChannels: [UInt8] = []
        if let services = device.services as? [IOBluetoothSDPServiceRecord] {
            for service in services {
                var chID: BluetoothRFCOMMChannelID = 0
                if service.getRFCOMMChannelID(&chID) == kIOReturnSuccess, chID > 0 {
                    let sName = (service.getServiceName() ?? "").uppercased()
                    let chUInt8 = UInt8(chID)
                    if !sdpChannels.contains(chUInt8) {
                        if sName.contains("GEAR") || sName.contains("SAMSUNG") || sName.contains("SPP") || sName.contains("BUDS") {
                            sdpChannels.insert(chUInt8, at: 0)
                        } else if chUInt8 >= 20 && chUInt8 <= 30 {
                            sdpChannels.append(chUInt8)
                        }
                    }
                }
            }
        }
        // Samsung Galaxy Buds standard SPP channels: 27 is the primary across Buds2 Pro / Buds Pro / Buds2
        let knownBudsSPPChannels: [UInt8] = [27, 28, 29, 26, 25, 24, 23, 22, 21, 20, 30]
        for def in knownBudsSPPChannels {
            if !sdpChannels.contains(def) { sdpChannels.append(def) }
        }

        candidateChannels = sdpChannels
        currentChannelIndex = 0
        tryNextChannel()
    }

    private var candidateChannels: [UInt8] = []
    private var currentChannelIndex: Int = 0
    private var targetDevice: IOBluetoothDevice?
    private var channelOpenTimeoutTask: Task<Void, Never>?

    private func tryNextChannel() {
        channelOpenTimeoutTask?.cancel()
        guard isConnecting, !cancelRequested, let device = targetDevice else { return }

        guard currentChannelIndex < candidateChannels.count else {
            isConnecting = false
            updateState(.disconnected)
            setStatus("Connection failed")
            ProtocolLogger.log(.warning, "All candidate RFCOMM channels exhausted for \(device.name ?? "device")")
            return
        }

        let cid = candidateChannels[currentChannelIndex]
        currentChannelIndex += 1
        ProtocolLogger.log(.info, "Opening RFCOMM channel \(cid) for \(device.name ?? "Galaxy Buds")...")

        let res = device.openRFCOMMChannelAsync(&self.rfcommChannel, withChannelID: cid, delegate: self)
        if res != kIOReturnSuccess {
            ProtocolLogger.log(.verbose, "openRFCOMMChannelAsync(\(cid)) returned: \(res)")
            tryNextChannel()
            return
        }

        channelOpenTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if self.isConnecting && self.connectionState != .connected {
                ProtocolLogger.log(.verbose, "Channel \(cid) attempt timed out, advancing...")
                self.tryNextChannel()
            }
        }
    }

    func isDeviceConnected(address: String) -> Bool {
        if let dev = IOBluetoothDevice(addressString: address) {
            return dev.isConnected()
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

    func sendData(_ data: [UInt8]) {
        guard let channel = self.rfcommChannel, channel.isOpen() else {
            ProtocolLogger.log(.error, "Cannot send: RFCOMM channel not open")
            return
        }

        rfcommQueue.async {
            var mutableData = data
            let result = mutableData.withUnsafeMutableBufferPointer { buffer in
                channel.writeSync(buffer.baseAddress!, length: UInt16(data.count))
            }

            if result != kIOReturnSuccess {
                Task { @MainActor in
                    ProtocolLogger.log(.error, "RFCOMM write failed: \(result)")
                }
            } else {
                Task { @MainActor in
                    ProtocolLogger.log(.verbose, "Sent \(data.count) bytes over RFCOMM")
                }
            }
        }
    }

    // MARK: - Disconnection

    func disconnect() {
        channelOpenTimeoutTask?.cancel()
        channelOpenTimeoutTask = nil
        cancelRequested = true
        isConnecting = false
        updateState(.disconnecting)
        setStatus("Disconnecting...")

        let channelToClose = rfcommChannel
        rfcommChannel = nil
        connectedDevice = nil
        targetDevice = nil

        rfcommQueue.async { [weak self] in
            channelToClose?.setDelegate(nil)
            channelToClose?.close()

            Task { @MainActor in
                self?.updateState(.disconnected)
                self?.setStatus("Disconnected")
                ProtocolLogger.log(.info, "Disconnected")
            }
        }
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
            if error == kIOReturnSuccess, let ch = channel {
                guard let dev = ch.getDevice() ?? self.targetDevice ?? self.connectedDevice else { return }
                self.setupChannel(ch, device: dev, deviceName: dev.name ?? "Galaxy Buds2 Pro")
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
            onDataReceived?(bytes)
        }
    }

    nonisolated func rfcommChannelClosed(_ channel: IOBluetoothRFCOMMChannel!) {
        Task { @MainActor in
            ProtocolLogger.log(.warning, "RFCOMM channel closed unexpectedly")
            self.updateState(.disconnected)
            self.setStatus("Connection lost")
        }
    }
}

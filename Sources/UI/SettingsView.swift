// SettingsView.swift
// Application settings with native macOS tab layout.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newName = ""

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            bluetoothTab.tabItem { Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right") }
            deviceTab.tabItem { Label("Device", systemImage: "earbuds") }
            advancedTab.tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(minWidth: 300, minHeight: 300)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Show battery in menu bar", isOn: $appState.showBatteryInMenuBar)
            Toggle("Auto-reconnect on launch", isOn: $appState.autoReconnect)
            Toggle("Launch at login", isOn: Binding(
                get: { DevicePersistence.launchAtLogin },
                set: { DevicePersistence.launchAtLogin = $0 }
            ))
        }
        .padding()
    }

    // MARK: - Bluetooth

    private var bluetoothTab: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(appState.deviceState.connectionState.description)
                        .foregroundColor(appState.deviceState.connectionState.isConnected ? .green : .secondary)
                }
                if let addr = DevicePersistence.lastDeviceAddress {
                    HStack {
                        Text("Address")
                        Spacer()
                        Text(addr).monospaced().font(.caption)
                    }
                }
                if let name = DevicePersistence.lastDeviceName {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(name)
                    }
                }
            }
            Section {
                Button("Scan for Devices") { appState.scanForDevices() }
                Button("Reconnect") { Task { await appState.reconnect() } }
                Button("Forget Device") { DevicePersistence.clearLastDevice() }
                    .foregroundColor(.red)
            }
            Section {
                Text("Galaxy Buds2 Pro use Bluetooth SPP (RFCOMM) for configuration.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Device

    private var deviceTab: some View {
        Form {
            Section("Rename") {
                HStack {
                    TextField("New name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button("Rename") {
                        Task { await appState.renameDevice(name: newName) }
                        newName = ""
                    }
                    .disabled(newName.isEmpty)
                }
                Text("Rename may not persist if the device reverts to its default name.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("System") {
                Button("Reboot Earbuds") { Task { await appState.rebootDevice() } }
                Button("Power Off") { Task { await appState.powerOffDevice() } }
                Button("Factory Reset") { Task { await appState.resetDevice() } }
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("Protocol") {
                Toggle("Enable protocol logging", isOn: Binding(
                    get: { ProtocolLogger.isEnabled },
                    set: { ProtocolLogger.isEnabled = $0 }
                ))
            }
            Section("Export") {
                Button("Export Protocol Log") {
                    let log = ProtocolLogger.exportText()
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.plainText]
                    panel.nameFieldStringValue = "galaxy_buds_protocol_log.txt"
                    panel.begin { result in
                        if result == .OK, let url = panel.url {
                            try? log.write(to: url, atomically: true, encoding: .utf8)
                        }
                    }
                }
                Button("Clear Protocol Log") { ProtocolLogger.clear() }
                    .foregroundColor(.red)
            }
            Section("Capability Matrix") {
                Text(CapabilityMatrix.summary())
                    .font(.caption).monospaced()
            }
            Section("macOS Compatibility & Limitations") {
                Text("• 360 Audio / Spatial Head Tracking: Requires Samsung OneUI spatial rendering framework (Android only).\n• Samsung Seamless Codec (SSC 24-bit): Requires Samsung kernel audio driver. macOS uses high-bitrate AAC.\n• Firmware Updates (FOTA): Gated on macOS for hardware safety.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// SettingsView.swift
// Application settings with native macOS tab layout.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var pendingAction: String?
    @State private var confirmAction = false
    @State private var launchAtLogin = DevicePersistence.launchAtLogin

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            bluetoothTab.tabItem { Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right") }
            deviceTab.tabItem { Label("Device", systemImage: "earbuds") }
            ScrollView { advancedTab }.tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(minWidth: 300, minHeight: 300)
        .alert(pendingAction ?? "Device action", isPresented: $confirmAction) {
            Button("Cancel", role: .cancel) {}
            Button(pendingAction ?? "Continue", role: .destructive) {
                Task {
                    switch pendingAction {
                    case "Factory Reset": await appState.resetDevice()
                    case "Power Off": await appState.powerOffDevice()
                    default: await appState.rebootDevice()
                    }
                }
            }
        } message: {
            Text(pendingAction == "Factory Reset" ? "This erases earbud settings and pairing information. You will need to pair again." : "This disconnects the earbuds from all connected devices.")
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Show battery in menu bar", isOn: $appState.showBatteryInMenuBar)
            Toggle("Connect automatically", isOn: $appState.autoReconnect)
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { value in
                    do {
                        try DevicePersistence.updateLaunchAtLogin(value)
                        launchAtLogin = DevicePersistence.launchAtLogin
                        if value && !launchAtLogin { appState.lastError = "Approve this app in System Settings → General → Login Items." }
                    } catch {
                        appState.lastError = "Could not change launch at login: \(error.localizedDescription)"
                    }
                }
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
                Button("Forget Device") { appState.forgetDevice() }
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
            Section("Device Name") {
                Text("Use Galaxy Wearable on your phone to rename the earbuds. This app remembers their Bluetooth address after connecting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Connections") {
                Toggle("Seamless connection", isOn: Binding(
                    get: { appState.deviceState.seamlessConnection },
                    set: { value in Task { await appState.setSeamlessConnection(value) } }
                ))
            }
            Section("System") {
                Button("Reboot Earbuds") { pendingAction = "Reboot Earbuds"; confirmAction = true }
                Button("Power Off") { pendingAction = "Power Off"; confirmAction = true }
                Button("Factory Reset") { pendingAction = "Factory Reset"; confirmAction = true }
                    .foregroundColor(.red)
            }
        }
        .padding()
        .disabled(!appState.canControl)
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

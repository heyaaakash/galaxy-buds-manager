import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: Section = .general
    @State private var pendingAction: String?
    @State private var confirmAction = false
    @State private var launchAtLogin = DevicePersistence.launchAtLogin

    private enum Section: String, CaseIterable {
        case general = "General"
        case bluetooth = "Bluetooth"
        case device = "Device"
        case advanced = "Advanced"
    }

    var body: some View {
        BudsPage {
            Picker("Settings section", selection: $selectedSection) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            sectionContent
        }
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

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general: generalSettings
        case .bluetooth: bluetoothSettings
        case .device: deviceSettings
        case .advanced: advancedSettings
        }
    }

    private var generalSettings: some View {
        BudsCard(title: "General", symbol: "gearshape") {
            Toggle("Show battery in menu bar", isOn: $appState.showBatteryInMenuBar)
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
            Text("The app attaches automatically when the earbuds connect to this Mac. It never connects them by itself.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var bluetoothSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            BudsCard(title: "Connection", symbol: "antenna.radiowaves.left.and.right") {
                BudsInfoRow(title: "Status", value: appState.deviceState.connectionState.description)
                if let name = appState.lastObservedBluetoothDeviceName,
                   let isGalaxyBuds = appState.lastObservedWasGalaxyBuds {
                    BudsInfoRow(title: "Observed device", value: name)
                    BudsInfoRow(title: "Galaxy Buds", value: isGalaxyBuds ? "Yes" : "No")
                }
                if let address = DevicePersistence.lastDeviceAddress {
                    BudsInfoRow(title: "Address", value: address)
                }
                if let name = DevicePersistence.lastDeviceName {
                    BudsInfoRow(title: "Name", value: name)
                }
            }
            BudsCard(title: "Actions", symbol: "arrow.triangle.2.circlepath") {
                HStack(spacing: 6) {
                    Button("Scan") { appState.scanForDevices() }
                    Button("Attach connected Buds") { Task { await appState.reconnect() } }
                    Button("Forget") { appState.forgetDevice() }
                        .foregroundStyle(.red)
                }
                .controlSize(.small)
                Text("Connect in macOS first. The app only opens settings on an existing Bluetooth connection.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var deviceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            BudsCard(title: "Device name", symbol: "pencil") {
                Text("Rename the earbuds in Galaxy Wearable on your phone. This app remembers their Bluetooth address.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            BudsCard(title: "Connections", symbol: "link") {
                Toggle("Seamless connection", isOn: Binding(
                    get: { appState.deviceState.seamlessConnection },
                    set: { value in Task { await appState.setSeamlessConnection(value) } }
                ))
                .disabled(!appState.canControl)
            }
            BudsCard(title: "System", symbol: "power") {
                HStack(spacing: 6) {
                    Button("Reboot") { pendingAction = "Reboot Earbuds"; confirmAction = true }
                    Button("Power Off") { pendingAction = "Power Off"; confirmAction = true }
                    Button("Factory Reset") { pendingAction = "Factory Reset"; confirmAction = true }
                        .foregroundStyle(.red)
                }
                .controlSize(.small)
                .disabled(!appState.canControl)
            }
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            BudsCard(title: "Protocol log", symbol: "doc.text") {
                Toggle("Enable protocol logging", isOn: Binding(
                    get: { ProtocolLogger.isEnabled },
                    set: { ProtocolLogger.isEnabled = $0 }
                ))
                HStack(spacing: 6) {
                    Button("Export Log") {
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
                    Button("Clear Log") { ProtocolLogger.clear() }
                        .foregroundStyle(.red)
                }
                .controlSize(.small)
            }
            BudsCard(title: "Capability matrix", symbol: "list.bullet.rectangle") {
                Text(CapabilityMatrix.summary())
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            BudsCard(title: "macOS compatibility", symbol: "info.circle") {
                Text("360 Audio and spatial head tracking require Samsung OneUI. Samsung Seamless Codec requires a Samsung audio driver. Firmware updates are unavailable in this app; use Galaxy Wearable.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

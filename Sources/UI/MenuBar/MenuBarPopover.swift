// MenuBarPopover.swift
// The main popover shown when clicking the menu bar icon.

import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var appState: AppState
    @State private var currentView: PopoverDetailView = .main

    enum PopoverDetailView: Equatable {
        case main
        case noiseControl
        case equalizer
        case touchControls
        case voiceDetect
        case findMyBuds
        case fitTest
        case deviceInfo
        case advanced
        case settings
        case debugLog
    }

    var body: some View {
        VStack(spacing: 0) {
            switch currentView {
            case .main:
                mainContent
            case .noiseControl:
                detailContainer(title: "Noise Control") {
                    NoiseControlSheet().environmentObject(appState)
                }
            case .equalizer:
                detailContainer(title: "Equalizer") {
                    EqualizerSheet().environmentObject(appState)
                }
            case .touchControls:
                detailContainer(title: "Touch Controls") {
                    TouchControlSheet().environmentObject(appState)
                }
            case .voiceDetect:
                detailContainer(title: "Voice Detect") {
                    VoiceDetectSheet().environmentObject(appState)
                }
            case .findMyBuds:
                detailContainer(title: "Find My Earbuds") {
                    FindMyEarbudsSheet().environmentObject(appState)
                }
            case .fitTest:
                detailContainer(title: "Fit Test") {
                    FitTestSheet().environmentObject(appState)
                }
            case .deviceInfo:
                detailContainer(title: "Device Info") {
                    DeviceInfoSheet().environmentObject(appState)
                }
            case .advanced:
                detailContainer(title: "Advanced Diagnostics") {
                    AdvancedDiagnosticsSheet().environmentObject(appState)
                }
            case .settings:
                detailContainer(title: "Settings") {
                    SettingsView().environmentObject(appState)
                }
            case .debugLog:
                detailContainer(title: "Protocol Log") {
                    debugLogView
                }
            }
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private var mainContent: some View {
        if appState.deviceState.connectionState.isConnected {
            connectedView
        } else if appState.deviceState.connectionState.isConnectingOrReconnecting {
            connectingView
        } else if appState.hasPairedDevices {
            pairedDeviceListView
        } else {
            disconnectedView
        }
    }

    private func detailContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentView = .main
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text("Back").font(.system(size: 12)).opacity(0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            content()
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 0) {
            deviceHeader
            Divider().padding(.horizontal, 12)
            batterySection
            Divider().padding(.horizontal, 12)
            noiseControlQuickSwitch
            Divider().padding(.horizontal, 12)
            quickInfoSection
            Divider().padding(.horizontal, 12)
            footerSection
        }
        .padding(.vertical, 8)
    }

    // MARK: - Device Header

    private var deviceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(appState.deviceState.deviceName)
                        .font(.system(size: 13, weight: .semibold))

                    if appState.availablePairedDevices.count > 1 {
                        Menu {
                            ForEach(appState.availablePairedDevices) { dev in
                                Button(dev.name) {
                                    Task { await appState.connectToPairedDevice(dev) }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                Text(connectionStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var connectionStatusText: String {
        if appState.deviceState.isAnyBudWorn { return "In Use" }
        return "Connected"
    }

    // MARK: - Connecting View

    private var connectingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .padding(.top, 16)

            Text("Connecting...")
                .font(.system(size: 13, weight: .semibold))

            Text(appState.bluetoothManager.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button("Cancel") { appState.disconnect() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Paired Device List

    private var pairedDeviceListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "earbuds")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Text("Galaxy Buds2 Pro")
                .font(.system(size: 13, weight: .semibold))

            Text("Select a device to connect:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(appState.availablePairedDevices) { device in
                    HStack {
                        Image(systemName: "earbuds")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name)
                                .font(.system(size: 12, weight: .medium))
                            Text(device.id)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Button("Connect") {
                            Task { await appState.connectToPairedDevice(device) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            .padding(.horizontal, 12)

            HStack {
                Button("Refresh") { appState.scanForDevices() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "earbuds")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Text("Galaxy Buds2 Pro")
                .font(.system(size: 13, weight: .semibold))

            if let error = appState.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            } else if let name = DevicePersistence.lastDeviceName {
                Text("Last: \(name)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button("Connect") {
                Task { await appState.reconnect() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Open Bluetooth Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.Bluetooth") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack {
                Button("Debug Log") { currentView = .debugLog }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Battery Section

    private var batterySection: some View {
        VStack(spacing: 6) {
            batteryRow(label: "Left", level: appState.deviceState.batteryLeft.level, icon: "earbuds.left")
            batteryRow(label: "Right", level: appState.deviceState.batteryRight.level, icon: "earbuds.right")
            batteryRow(label: "Case", level: appState.deviceState.batteryCase.level, icon: "batterycaseportrait")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func batteryRow(label: String, level: Int?, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .frame(width: 36, alignment: .leading)
            if let level = level {
                ProgressView(value: Double(level), total: 100)
                    .tint(batteryColor(for: level))
                    .frame(height: 4)
                Text("\(level)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 32, alignment: .trailing)
            } else {
                ProgressView(value: 0, total: 100).frame(height: 4).opacity(0.3)
                Text("--")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private func batteryColor(for level: Int) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .orange }
        return .red
    }

    // MARK: - Noise Control Quick Switch

    private var noiseControlQuickSwitch: some View {
        HStack(spacing: 0) {
            ForEach([NoiseControlMode.anc, .ambient, .off], id: \.rawValue) { mode in
                Button {
                    Task { await appState.setNoiseControl(mode: mode) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon).font(.system(size: 11))
                        Text(mode.description).font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.deviceState.noiseControlMode == mode
                                  ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.deviceState.noiseControlMode == mode
                                    ? Color.accentColor.opacity(0.3)
                                    : Color.secondary.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.fullDescription)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Quick Info Section

    private var quickInfoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "speaker.wave.2", label: "Equalizer", value: appState.deviceState.equalizerPreset.description) {
                currentView = .equalizer
            }
            infoRow(icon: "hand.tap", label: "Touch Controls", value: appState.deviceState.touchpadLocked ? "Locked" : ">") {
                currentView = .touchControls
            }
            infoRow(icon: "waveform", label: "Voice Detect", value: appState.deviceState.detectConversations ? "ON" : "OFF") {
                currentView = .voiceDetect
            }
            infoRow(icon: "magnifyingglass", label: "Find My Earbuds", value: nil) {
                currentView = .findMyBuds
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func infoRow(icon: String, label: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(label).font(.system(size: 12))
                Spacer()
                if let value = value {
                    Text(value).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            Button("Settings") { currentView = .settings }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button("Device Info") { currentView = .deviceInfo }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button("Debug") { currentView = .debugLog }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Debug Log View

    private var debugLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(ProtocolLogger.exportText())
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ProtocolLogger.exportText(), forType: .string)
                }
                .controlSize(.small)

                Button("Open Folder") {
                    ProtocolLogger.openLogFolder()
                }
                .controlSize(.small)

                Button("Clear") {
                    ProtocolLogger.clear()
                }
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(12)
    }
}

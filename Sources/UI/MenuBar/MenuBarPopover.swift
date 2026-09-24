// MenuBarPopover.swift
// The main popover shown when clicking the menu bar icon.

import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var appState: AppState
    @State private var currentView: PopoverDetailView = .main
    @State private var windowSizer = PopoverWindowSizer()

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
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: appState.deviceState.connectionState) { _, state in
            if !state.isConnected, currentView != .settings, currentView != .debugLog { currentView = .main }
        }
        .safeAreaInset(edge: .bottom) {
            if let error = appState.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .textSelection(.enabled)
                    Spacer(minLength: 4)
                    Button { appState.lastError = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss message")
                }
                .padding(11)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.12))
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { windowSizer.setContentHeight(geometry.size.height) }
                    .onChange(of: geometry.size.height) { _, height in
                        windowSizer.setContentHeight(height)
                    }
            }
        }
        .background(PopoverWindowAccessor(sizer: windowSizer))
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
        PopoverDetailContainer(
            title: title,
            isContentEnabled: currentView == .settings || currentView == .debugLog || appState.canControl,
            onBack: { currentView = .main },
            content: content
        )
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 0) {
            deviceHeader
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

            Divider()

            batterySection
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            if !appState.deviceState.hasReceivedStatus {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text(appState.activeProfile.hasControls ? "Syncing settings…" : "Waiting for battery status…")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 7)
            }
            if !appState.deviceState.pendingCommands.isEmpty {
                Text("Applying setting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 7)
            }

            if appState.activeProfile.hasControls {
                Divider()

                noiseControlQuickSwitch
                    .disabled(!appState.canControl)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()

                quickInfoSection
                    .disabled(!appState.canControl)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            } else {
                Text("Battery display only for this model. Controls are unavailable until its protocol is verified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            Divider()

            footerSection
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Device Header

    private var deviceHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: "earbuds")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.deviceState.deviceName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text(connectionStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)

            if appState.availablePairedDevices.count > 1 {
                Menu {
                    ForEach(appState.availablePairedDevices) { dev in
                        Button(dev.name) {
                            Task { await appState.connectToPairedDevice(dev) }
                        }
                        .disabled(!dev.canAttach)
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Switch paired device")
            }
        }
    }

    private var connectionStatusText: String {
        if appState.deviceState.isAnyBudWorn { return "In Use" }
        return "Connected"
    }

    // MARK: - Connecting View

    private var connectingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .frame(width: 40, height: 40)
            Text("Connecting to your earbuds")
                .font(.system(size: 14, weight: .semibold))
            if !appState.bluetoothManager.statusMessage.isEmpty {
                Text(appState.bluetoothManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Cancel") { appState.disconnect() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Paired Device List

    private var pairedDeviceListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "earbuds")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            Text("Choose your earbuds")
                .font(.system(size: 14, weight: .semibold))

            BudsCard(title: "Paired devices", symbol: "antenna.radiowaves.left.and.right") {
                VStack(spacing: 10) {
                    ForEach(appState.availablePairedDevices) { device in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(device.id)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(device.isSystemConnected ? "Connected in macOS" : "Connect in macOS first")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                if !device.profile.hasControls {
                                    Text(device.profile.canConnect ? "Battery only" : "Protocol not supported")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 4)
                            Button("Attach") {
                                Task { await appState.connectToPairedDevice(device) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!device.canAttach)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Refresh") { appState.scanForDevices() }
                Button("Settings") { currentView = .settings }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .font(.system(size: 11))
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: BudsUI.width, alignment: .leading)
    }

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "earbuds")
                .font(.system(size: 24))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            Text("Galaxy Buds")
                .font(.system(size: 14, weight: .semibold))

            Text("Pair your earbuds in Bluetooth settings, then open their case to connect.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let name = DevicePersistence.lastDeviceName {
                Text("Last: \(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Check connection") {
                    Task { await appState.reconnect() }
                }
                .buttonStyle(.borderedProminent)

                Button("Bluetooth Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.Bluetooth") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)

            Divider()
            HStack(spacing: 12) {
                Button("Settings") { currentView = .settings }
                Button("Debug Log") { currentView = .debugLog }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .font(.system(size: 11))
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: BudsUI.width, alignment: .leading)
    }

    // MARK: - Battery Section

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Battery", symbol: "battery.100percent")
            HStack(spacing: 7) {
                batteryTile(label: "Left", battery: appState.deviceState.batteryLeft, icon: "earbuds")
                batteryTile(label: "Right", battery: appState.deviceState.batteryRight, icon: "earbuds")
                batteryTile(label: "Case", battery: appState.deviceState.batteryCase, icon: "batterycase")
            }
        }
    }

    private func batteryTile(label: String, battery: BatteryState, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(label)
                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Text(battery.levelString)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(battery.level == nil ? .secondary : .primary)

            ProgressView(value: Double(battery.level ?? 0), total: 100)
                .tint(battery.level.map(batteryColor(for:)) ?? .secondary)
                .opacity(battery.level == nil ? 0.35 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) battery \(battery.levelString)\(battery.isCharging ? ", charging" : "")")
    }

    private func batteryColor(for level: Int) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .orange }
        return .red
    }

    // MARK: - Noise Control Quick Switch

    private var noiseControlQuickSwitch: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Noise control", symbol: "waveform")
            Picker("Noise control", selection: Binding(
                get: { appState.deviceState.noiseControlMode },
                set: { mode in Task { await appState.setNoiseControl(mode: mode) } }
            )) {
                ForEach([NoiseControlMode.anc, .ambient, .off], id: \.rawValue) { mode in
                    Text(mode.description).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Quick Info Section

    private var quickInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Sound", symbol: "speaker.wave.2")
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            infoRow(icon: "waveform.path", label: "Noise settings", value: nil) { currentView = .noiseControl }
            infoRow(icon: "slider.horizontal.3", label: "Equalizer", value: appState.deviceState.equalizerPreset.description) {
                currentView = .equalizer
            }
            infoRow(icon: "hand.tap", label: "Touch controls", value: appState.deviceState.touchpadLocked ? "Locked" : nil) {
                currentView = .touchControls
            }
            infoRow(icon: "waveform", label: "Voice Detect", value: appState.deviceState.detectConversations ? "On" : "Off") {
                currentView = .voiceDetect
            }

            Divider()
                .padding(.horizontal, 6)
                .padding(.vertical, 5)

            sectionHeader("Utilities", symbol: "square.grid.2x2")
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            infoRow(icon: "ear.badge.checkmark", label: "Earbud fit test", value: nil) { currentView = .fitTest }
            infoRow(icon: "magnifyingglass", label: "Find my earbuds", value: nil) { currentView = .findMyBuds }
            infoRow(icon: "wrench.and.screwdriver", label: "Diagnostics", value: nil) { currentView = .advanced }
        }
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func infoRow(icon: String, label: String, value: String?, action: @escaping () -> Void) -> some View {
        BudsNavigationRow(title: label, symbol: icon, value: value, action: action)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 10) {
            Button("Disconnect") { appState.disconnect() }
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button {
                currentView = .settings
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
                currentView = .deviceInfo
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            Menu {
                Button("Protocol Log") { currentView = .debugLog }
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("More options")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .font(.system(size: 11))
        .buttonStyle(.borderless)
    }

    // MARK: - Debug Log View

    private var debugLogView: some View {
        let log = ProtocolLogger.exportText()
        return BudsPage {
            BudsCard(title: "Session log", symbol: "doc.text") {
                if log.isEmpty {
                    Text("No log entries yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(log)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(log, forType: .string)
                    }
                    Button("Open Folder") {
                        ProtocolLogger.openLogFolder()
                    }
                    Button("Clear") {
                        ProtocolLogger.clear()
                    }
                }
                .controlSize(.small)
            }
        }
    }
}

private struct PopoverDetailContainer<Content: View>: View {
    let title: String
    let isContentEnabled: Bool
    let onBack: () -> Void
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 440

    private var maximumContentHeight: CGFloat {
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 520
        return min(440, max(260, visibleHeight - 90))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 3)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to device menu")
                Spacer()
            }
            .overlay {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color(nsColor: .windowBackgroundColor))
            .zIndex(1)

            Divider()

            ScrollView {
                content
                    .disabled(!isContentEnabled)
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear { updateContentHeight(geometry.size.height) }
                                .onChange(of: geometry.size.height) { _, height in
                                    updateContentHeight(height)
                                }
                        }
                    }
            }
            .frame(height: min(contentHeight, maximumContentHeight))
            .scrollIndicators(.visible)
            .clipped()
        }
    }

    private func updateContentHeight(_ height: CGFloat) {
        if height > 0 { contentHeight = height }
    }
}

@MainActor
private final class PopoverWindowSizer {
    weak var window: NSWindow?
    private var contentHeight: CGFloat = 0

    func setWindow(_ window: NSWindow?) {
        self.window = window
        resizeIfNeeded()
    }

    func setContentHeight(_ height: CGFloat) {
        contentHeight = height
        resizeIfNeeded()
    }

    private func resizeIfNeeded() {
        guard let window, contentHeight > 0,
              abs(window.contentLayoutRect.height - contentHeight) > 1 else { return }

        // MenuBarExtra retains its previous window height after a shorter page appears.
        // Keep its top edge anchored while removing that unused space.
        let top = window.frame.maxY
        window.setContentSize(NSSize(width: 320, height: contentHeight))
        var frame = window.frame
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true)
    }
}

private struct PopoverWindowAccessor: NSViewRepresentable {
    let sizer: PopoverWindowSizer

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { sizer.setWindow(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { sizer.setWindow(view.window) }
    }
}

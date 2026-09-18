// GalaxyBudsManagerApp.swift
// Menu-bar-first macOS utility for Samsung Galaxy Buds2 Pro.

import SwiftUI

@main
struct GalaxyBudsManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — this is a menu-bar-only app
        NSApp.setActivationPolicy(.accessory)
        ProtocolLogger.setupLogDirectory()
        ProtocolLogger.log(.info, "Galaxy Buds2 Pro Manager started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProtocolLogger.log(.info, "Application terminating")
    }
}

// MARK: - Menu Bar Menu

/// The menu shown when clicking the menu bar icon.
/// Uses native macOS menu (not a SwiftUI popover) for reliable interaction.
struct MenuBarMenu: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        // Device header
        if appState.deviceState.connectionState.isConnected {
            connectedMenuContent
        } else if appState.deviceState.connectionState.isConnectingOrReconnecting {
            connectingMenuContent
        } else {
            disconnectedMenuContent
        }
    }

    // MARK: - Connected Menu

    private var connectedMenuContent: some View {
        Group {
            // Device name
            Text("● \(appState.deviceState.deviceName)")
                .font(.system(size: 13, weight: .semibold))

            Text("Connected" + (appState.deviceState.isAnyBudWorn ? " • In Ear" : ""))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

            // Battery levels
            batteryRow(label: "Left", level: appState.deviceState.batteryLeft.level)
            batteryRow(label: "Right", level: appState.deviceState.batteryRight.level)
            batteryRow(label: "Case", level: appState.deviceState.batteryCase.level)

            Divider()

            // Noise control
            noiseControlMenu

            Divider()

            // Quick actions
            Button("Equalizer: \(appState.deviceState.equalizerPreset.description)") {
                // Open settings window
                openSettings()
            }

            Button("Touch Controls") {
                openSettings()
            }

            Button(appState.deviceState.detectConversations ? "Voice Detect: ON" : "Voice Detect: OFF") {
                Task { await appState.setDetectConversations(!appState.deviceState.detectConversations) }
            }

            Button("Find My Earbuds") {
                openSettings()
            }

            Divider()

            Button("Device Info") {
                openSettings()
            }

            Button("Settings...") {
                openSettings()
            }

            Divider()

            Button("Disconnect") {
                appState.disconnect()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    // MARK: - Connecting Menu

    private var connectingMenuContent: some View {
        Group {
            Text(appState.deviceState.connectionState.description)
                .font(.system(size: 13, weight: .semibold))

            if !appState.bluetoothManager.statusMessage.isEmpty {
                Text(appState.bluetoothManager.statusMessage)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
            }

            Divider()

            Button("Cancel") {
                appState.disconnect()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    // MARK: - Disconnected Menu

    private var disconnectedMenuContent: some View {
        Group {
            Text("Galaxy Buds2 Pro unavailable")
                .font(.system(size: 13, weight: .semibold))

            if let error = appState.lastError {
                Text(error)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
            } else if let name = DevicePersistence.lastDeviceName {
                Text("Last: \(name)")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Show paired devices
            if appState.hasPairedDevices {
                ForEach(appState.availablePairedDevices) { device in
                    Button("Connect to \(device.name)") {
                        Task { await appState.connectToPairedDevice(device) }
                    }
                }
                Divider()
            }

            Button("Scan for Devices") {
                appState.scanForDevices()
            }

            Button("Open Bluetooth Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.Bluetooth") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("Debug Log") {
                openSettings()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    // MARK: - Noise Control Menu

    private var noiseControlMenu: some View {
        Group {
            Button(appState.deviceState.noiseControlMode == .anc ? "✓ Active Noise Cancelling" : "   Active Noise Cancelling") {
                Task { await appState.setNoiseControl(mode: .anc) }
            }

            Button(appState.deviceState.noiseControlMode == .ambient ? "✓ Ambient Sound" : "   Ambient Sound") {
                Task { await appState.setNoiseControl(mode: .ambient) }
            }

            Button(appState.deviceState.noiseControlMode == .off ? "✓ Noise Control Off" : "   Noise Control Off") {
                Task { await appState.setNoiseControl(mode: .off) }
            }
        }
    }

    // MARK: - Helpers

    private func batteryRow(label: String, level: Int?) -> some View {
        if let level = level {
            return Text("\(label)\t\t\(level)%")
        } else {
            return Text("\(label)\t\t--")
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

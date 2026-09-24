// MenuBarLabel.swift
// The small icon displayed in the macOS menu bar.

import SwiftUI

/// The menu bar icon that indicates device connection state.
struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: sfSymbolName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 14))

            if appState.deviceState.connectionState.isConnected,
               appState.showBatteryInMenuBar,
               let avg = appState.deviceState.averageBattery {
                Text("\(avg)%")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(iconColor)
        .accessibilityLabel(accessibilityDescription)
    }

    private var sfSymbolName: String {
        return "earbuds"
    }

    private var iconColor: Color {
        switch appState.deviceState.connectionState {
        case .connected:
            return .primary
        case .connecting, .reconnecting, .scanning:
            return .primary
        case .error, .disconnected, .disconnecting:
            return .secondary
        }
    }

    private var accessibilityDescription: String {
        switch appState.deviceState.connectionState {
        case .connected:
            let name = appState.deviceState.deviceName
            if let avg = appState.deviceState.averageBattery {
                return "\(name) connected, \(avg)% battery"
            }
            return "\(name) connected"
        case .scanning:
            return "Scanning for Galaxy Buds"
        case .connecting:
            return "Connecting to Galaxy Buds"
        case .reconnecting(let n):
            return "Reconnecting to Galaxy Buds, attempt \(n)"
        case .error:
            return "Bluetooth error"
        default:
            return "Galaxy Buds disconnected"
        }
    }
}

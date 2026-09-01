// AdvancedDiagnosticsView.swift
// Advanced diagnostics and device management sheet.

import SwiftUI

struct AdvancedDiagnosticsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.bordered).controlSize(.small)
            }

            // Device Management
            GroupBox("Device Management") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Reboot") { Task { await appState.rebootDevice() } }.controlSize(.small)
                        Button("Power Off") { Task { await appState.powerOffDevice() } }.controlSize(.small)
                        Button("Factory Reset") { showResetConfirm = true }
                            .controlSize(.small).foregroundColor(.red)
                    }
                    Text("These commands affect the earbuds directly.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .alert("Factory Reset", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task { await appState.resetDevice() }
                }
            } message: {
                Text("This will erase all settings on the earbuds. This cannot be undone.")
            }

            // Diagnostics
            GroupBox("Diagnostics") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Read Debug Data") { Task { await appState.requestDebugAllData() } }
                        .controlSize(.small)
                    if !appState.deviceState.debugDataRaw.isEmpty {
                        ScrollView(.horizontal) {
                            Text(appState.deviceState.debugDataRaw.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " "))
                                .font(.system(size: 9, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 40)
                    }
                }
            }

            // Firmware Info
            GroupBox("Firmware") {
                VStack(alignment: .leading, spacing: 4) {
                    if let cycles = appState.deviceState.batteryCycles {
                        infoRow("Battery Cycles", "\(cycles)")
                    }
                    HStack {
                        Button("Read Cycles") { Task { await appState.requestBatteryCycles() } }.controlSize(.small)
                    }
                    Text("Firmware updates (FOTA) are NOT supported. Use Samsung's official app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.system(size: 12))
    }
}

// DeviceInfoView.swift
// Device information sheet.

import SwiftUI

struct DeviceInfoSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            GroupBox {
                infoRow("Name", appState.deviceState.deviceName)
                infoRow("Model", "SM-R510")
                infoRow("Firmware", appState.deviceState.firmwareVersion.isEmpty ? "—" : appState.deviceState.firmwareVersion)
                infoRow("Serial", appState.deviceState.serialNumber.isEmpty ? "—" : appState.deviceState.serialNumber)
                infoRow("Cradle", appState.deviceState.cradleSerialNumber.isEmpty ? "—" : appState.deviceState.cradleSerialNumber)
                infoRow("Color L/R", "\(appState.deviceState.colorLeft) / \(appState.deviceState.colorRight)")
            }

            GroupBox {
                infoRow("Left Ear", appState.deviceState.wearingLeft.description)
                infoRow("Right Ear", appState.deviceState.wearingRight.description)
                infoRow("Main", appState.deviceState.mainConnection.description)
                infoRow("Coupled", appState.deviceState.isCoupled ? "Yes" : "No")
            }

            GroupBox {
                HStack {
                    Button("Read Serial") { Task { await appState.requestSerialNumber() } }.controlSize(.small)
                    Button("Read Build") { Task { await appState.requestBuildInfo() } }.controlSize(.small)
                    Button("Read SKU") { Task { await appState.requestSku() } }.controlSize(.small)
                }
                if !appState.deviceState.buildInfo.isEmpty {
                    infoRow("Build", appState.deviceState.buildInfo)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Text(value).fontWeight(.medium)
            Spacer()
        }
        .font(.system(size: 12))
    }
}

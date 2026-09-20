import SwiftUI

struct DeviceInfoSheet: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        BudsPage {
            BudsCard(title: "Device", symbol: "earbuds") {
                BudsInfoRow(title: "Name", value: appState.deviceState.deviceName)
                BudsInfoRow(title: "Model", value: "SM-R510")
                BudsInfoRow(title: "Firmware", value: appState.deviceState.firmwareVersion.isEmpty ? "—" : appState.deviceState.firmwareVersion)
                BudsInfoRow(title: "Serial", value: appState.deviceState.serialNumber.isEmpty ? "—" : appState.deviceState.serialNumber)
                BudsInfoRow(title: "Cradle", value: appState.deviceState.cradleSerialNumber.isEmpty ? "—" : appState.deviceState.cradleSerialNumber)
                BudsInfoRow(title: "Color L/R", value: "\(appState.deviceState.colorLeft) / \(appState.deviceState.colorRight)")
            }

            BudsCard(title: "Connection", symbol: "antenna.radiowaves.left.and.right") {
                BudsInfoRow(title: "Left ear", value: appState.deviceState.wearingLeft.description)
                BudsInfoRow(title: "Right ear", value: appState.deviceState.wearingRight.description)
                BudsInfoRow(title: "Main", value: appState.deviceState.mainConnection.description)
                BudsInfoRow(title: "Coupled", value: appState.deviceState.isCoupled ? "Yes" : "No")
            }

            BudsCard(title: "More information", symbol: "info.circle") {
                HStack(spacing: 6) {
                    Button("Read Serial") { Task { await appState.requestSerialNumber() } }
                    Button("Read Build") { Task { await appState.requestBuildInfo() } }
                    Button("Read SKU") { Task { await appState.requestSku() } }
                }
                .controlSize(.small)
                if !appState.deviceState.buildInfo.isEmpty {
                    BudsInfoRow(title: "Build", value: appState.deviceState.buildInfo)
                }
            }
        }
    }
}

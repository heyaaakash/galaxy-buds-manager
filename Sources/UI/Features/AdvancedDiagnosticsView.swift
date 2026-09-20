import SwiftUI

struct AdvancedDiagnosticsSheet: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        BudsPage {
            BudsCard(title: "Diagnostics", symbol: "waveform.path.ecg") {
                Button("Read debug data") { Task { await appState.requestDebugAllData() } }
                    .controlSize(.small)
                if !appState.deviceState.debugDataRaw.isEmpty {
                    ScrollView(.horizontal) {
                        Text(appState.deviceState.debugDataRaw.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " "))
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 40)
                }
            }

            BudsCard(title: "Firmware", symbol: "cpu") {
                if let cycles = appState.deviceState.batteryCycles {
                    BudsInfoRow(title: "Battery cycles", value: "\(cycles)")
                }
                Button("Read battery cycles") { Task { await appState.requestBatteryCycles() } }
                    .controlSize(.small)
                Text("Firmware updates are available through Samsung Galaxy Wearable.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text("For reboot, power off, or factory reset, open Settings → Device.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 2)
        }
    }
}

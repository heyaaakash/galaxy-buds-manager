// FindMyEarbudsView.swift
// Find My Earbuds sheet.

import SwiftUI

struct FindMyEarbudsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Remove the earbuds from your ears before starting. Plays a sound to help locate nearby earbuds.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("Start") {
                    Task { await appState.startFindMyEarbuds() }
                }
                .disabled(appState.deviceState.findMyActive || appState.deviceState.isAnyBudWorn)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Stop") {
                    Task { await appState.stopFindMyEarbuds() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if appState.deviceState.findMyActive {
                Divider()
                Text("Mute Individual Buds").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Toggle("Mute Left", isOn: Binding(
                    get: { appState.deviceState.findMyLeftMuted },
                    set: { val in Task { await appState.muteFindMyEarbud(left: val, right: appState.deviceState.findMyRightMuted) } }
                ))
                Toggle("Mute Right", isOn: Binding(
                    get: { appState.deviceState.findMyRightMuted },
                    set: { val in Task { await appState.muteFindMyEarbud(left: appState.deviceState.findMyLeftMuted, right: val) } }
                ))
            }
        }
        .padding(16)
        .frame(width: 320)
        .onDisappear {
            if appState.deviceState.findMyActive { Task { await appState.stopFindMyEarbuds() } }
        }
    }
}

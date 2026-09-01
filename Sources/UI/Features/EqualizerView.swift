// EqualizerView.swift
// Equalizer preset selection sheet.

import SwiftUI

struct EqualizerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            ForEach(EqualizerPreset.allCases, id: \.rawValue) { preset in
                Button {
                    Task { await appState.setEqualizer(preset: preset) }
                } label: {
                    HStack {
                        Text(preset.description)
                        Spacer()
                        if appState.deviceState.equalizerPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Toggle("Game Mode (Low Latency)", isOn: Binding(
                get: { appState.deviceState.gameModeEnabled },
                set: { val in Task { await appState.setGameMode(val) } }
            ))
        }
        .padding(16)
        .frame(width: 320)
    }
}

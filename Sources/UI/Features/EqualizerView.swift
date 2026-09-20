// EqualizerView.swift
// Equalizer preset selection sheet.

import SwiftUI

struct EqualizerSheet: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        BudsPage {
            BudsCard(title: "Sound profile", symbol: "slider.horizontal.3") {
                VStack(spacing: 1) {
                    ForEach(EqualizerPreset.allCases, id: \.rawValue) { preset in
                        BudsChoiceRow(
                            title: preset.description,
                            isSelected: appState.deviceState.equalizerPreset == preset
                        ) {
                            Task { await appState.setEqualizer(preset: preset) }
                        }
                    }
                }
            }

            BudsCard(title: "Left / right balance", symbol: "speaker.wave.2") {
                Slider(value: Binding(
                    get: { Double(appState.deviceState.stereoBalance) },
                    set: { value in Task { await appState.setStereoBalance(Int(value)) } }
                ), in: 0...32, step: 1)
                HStack {
                    Text("Left")
                    Spacer()
                    Button("Center") { Task { await appState.setStereoBalance(16) } }
                        .buttonStyle(.borderless)
                    Spacer()
                    Text("Right")
                }
                    .font(.caption)
            }

            BudsCard(title: "Playback", symbol: "gamecontroller") {
                Toggle("Game mode (low latency)", isOn: Binding(
                    get: { appState.deviceState.gameModeEnabled },
                    set: { val in Task { await appState.setGameMode(val) } }
                ))
            }
        }
    }
}

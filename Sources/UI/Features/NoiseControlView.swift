// NoiseControlView.swift
// Noise control settings sheet.

import SwiftUI

/// Sheet for noise control settings.
struct NoiseControlSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mode picker
            Picker("Mode", selection: Binding(
                get: { appState.deviceState.noiseControlMode },
                set: { val in Task { await appState.setNoiseControl(mode: val) } }
            )) {
                ForEach([NoiseControlMode.anc, .ambient, .off], id: \.rawValue) { mode in
                    Text(mode.fullDescription).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Ambient options
            if appState.deviceState.ambientEnabled {
                GroupBox("Ambient Volume") {
                    HStack {
                        Text("Level")
                        Spacer()
                        Text("\(appState.deviceState.ambientVolume)")
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(appState.deviceState.ambientVolume) },
                        set: { val in Task { await appState.setAmbientVolume(Int(val)) } }
                    ), in: 0...2, step: 1)
                }

                Toggle("Extra High Ambient", isOn: Binding(
                    get: { appState.deviceState.extraHighAmbient },
                    set: { val in Task { await appState.setExtraHighAmbient(val) } }
                ))
            }

            // Options
            Toggle("ANC with One Earbud", isOn: Binding(
                get: { appState.deviceState.ancWithOneEarbud },
                set: { val in Task { await appState.setAncWithOneEarbud(val) } }
            ))
        }
        .padding(16)
        .frame(width: 320)
    }
}

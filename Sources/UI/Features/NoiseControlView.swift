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
                    Text(mode.description).tag(mode)
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
                    ), in: 0...(appState.deviceState.extraHighAmbient ? 3 : 2), step: 1)
                }

                Toggle("Extra High Ambient", isOn: Binding(
                    get: { appState.deviceState.extraHighAmbient },
                    set: { val in Task { await appState.setExtraHighAmbient(val) } }
                ))
                .disabled(appState.deviceState.interfaceRevision < 13)
                Toggle("Customize ambient sound", isOn: Binding(
                    get: { appState.deviceState.customAmbientEnabled },
                    set: { value in Task { await appState.setCustomAmbient(enabled: value) } }
                ))
                if appState.deviceState.customAmbientEnabled {
                    ambientPicker("Left volume", value: appState.deviceState.customAmbientLeft,
                                  maximum: appState.deviceState.extraHighAmbient ? 4 : 2) { value in
                        Task { await appState.setCustomAmbient(left: value) }
                    }
                    ambientPicker("Right volume", value: appState.deviceState.customAmbientRight,
                                  maximum: appState.deviceState.extraHighAmbient ? 4 : 2) { value in
                        Task { await appState.setCustomAmbient(right: value) }
                    }
                    ambientPicker("Tone (soft to clear)", value: appState.deviceState.customAmbientTone, maximum: 4) { value in
                        Task { await appState.setCustomAmbient(tone: value) }
                    }
                }
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
    private func ambientPicker(_ title: String, value: Int, maximum: Int, change: @escaping (Int) -> Void) -> some View {
        Picker(title, selection: Binding(get: { min(value, maximum) }, set: change)) {
            ForEach(0...maximum, id: \.self) { Text("\($0 + 1)").tag($0) }
        }
    }

}

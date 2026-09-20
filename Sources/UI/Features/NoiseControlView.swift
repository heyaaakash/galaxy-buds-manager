// NoiseControlView.swift
// Noise control settings sheet.

import SwiftUI

/// Sheet for noise control settings.
struct NoiseControlSheet: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        BudsPage {
            BudsCard(title: "Listening mode", symbol: "waveform") {
                Picker("Mode", selection: Binding(
                    get: { appState.deviceState.noiseControlMode },
                    set: { val in Task { await appState.setNoiseControl(mode: val) } }
                )) {
                    ForEach([NoiseControlMode.anc, .ambient, .off], id: \.rawValue) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if appState.deviceState.ambientEnabled {
                BudsCard(title: "Ambient sound", symbol: "ear") {
                    HStack {
                        Text("Volume").font(.system(size: 12))
                        Spacer()
                        Text("\(appState.deviceState.ambientVolume)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(appState.deviceState.ambientVolume) },
                        set: { val in Task { await appState.setAmbientVolume(Int(val)) } }
                    ), in: 0...(appState.deviceState.extraHighAmbient ? 3 : 2), step: 1)
                    Toggle("Extra high volume", isOn: Binding(
                        get: { appState.deviceState.extraHighAmbient },
                        set: { val in Task { await appState.setExtraHighAmbient(val) } }
                    ))
                    .disabled(appState.deviceState.interfaceRevision < 13)
                    Toggle("Customize ambient sound", isOn: Binding(
                        get: { appState.deviceState.customAmbientEnabled },
                        set: { value in Task { await appState.setCustomAmbient(enabled: value) } }
                    ))
                    if appState.deviceState.customAmbientEnabled {
                        Divider()
                        ambientPicker("Left volume", value: appState.deviceState.customAmbientLeft,
                                      maximum: appState.deviceState.extraHighAmbient ? 4 : 2) { value in
                            Task { await appState.setCustomAmbient(left: value) }
                        }
                        ambientPicker("Right volume", value: appState.deviceState.customAmbientRight,
                                      maximum: appState.deviceState.extraHighAmbient ? 4 : 2) { value in
                            Task { await appState.setCustomAmbient(right: value) }
                        }
                        ambientPicker("Tone", value: appState.deviceState.customAmbientTone, maximum: 4) { value in
                            Task { await appState.setCustomAmbient(tone: value) }
                        }
                    }
                }
            }

            BudsCard(title: "More options", symbol: "earbuds") {
                Toggle("ANC with one earbud", isOn: Binding(
                    get: { appState.deviceState.ancWithOneEarbud },
                    set: { val in Task { await appState.setAncWithOneEarbud(val) } }
                ))
            }
        }
    }
    private func ambientPicker(_ title: String, value: Int, maximum: Int, change: @escaping (Int) -> Void) -> some View {
        Picker(title, selection: Binding(get: { min(value, maximum) }, set: change)) {
            ForEach(0...maximum, id: \.self) { Text("\($0 + 1)").tag($0) }
        }
    }

}

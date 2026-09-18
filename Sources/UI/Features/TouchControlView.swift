// TouchControlView.swift
// Touch control configuration sheet.

import SwiftUI

struct TouchControlSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Toggle("Lock Touch Controls", isOn: Binding(
                get: { appState.deviceState.touchpadLocked },
                set: { val in Task { await appState.setTouchpadLocked(val) } }
            ))

            GroupBox("Allowed gestures") {
                VStack(alignment: .leading, spacing: 8) {
                    tapToggle("Single tap", bit: 3)
                    tapToggle("Double tap", bit: 2)
                    tapToggle("Triple tap", bit: 1)
                    tapToggle("Touch and hold", bit: 0)
                    if appState.deviceState.interfaceRevision >= 1 {
                        tapToggle("Double tap for calls", bit: 4)
                        tapToggle("Touch and hold for calls", bit: 5)
                    }
                }
                .disabled(appState.deviceState.touchpadLocked)
            }
            Toggle("Double tap earbud edge for volume", isOn: Binding(
                get: { appState.deviceState.doubleTapVolume },
                set: { value in Task { await appState.setDoubleTapVolume(value) } }
            ))
            Text("Spotify and voice assistant actions depend on the connected phone or Mac app.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()

            Text("Long Press — Left").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            ForEach([TouchAction.voiceAssistant, .noiseControl, .volume, .spotifySpotOn], id: \.rawValue) { action in
                Button {
                    Task { await appState.setTouchActions(left: action, right: appState.deviceState.touchRightAction) }
                } label: {
                    HStack {
                        Text(action.description)
                        Spacer()
                        if appState.deviceState.touchLeftAction == action {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Text("Long Press — Right").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            ForEach([TouchAction.voiceAssistant, .noiseControl, .volume, .spotifySpotOn], id: \.rawValue) { action in
                Button {
                    Task { await appState.setTouchActions(left: appState.deviceState.touchLeftAction, right: action) }
                } label: {
                    HStack {
                        Text(action.description)
                        Spacer()
                        if appState.deviceState.touchRightAction == action {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
    private func tapToggle(_ title: String, bit: UInt8) -> some View {
        Toggle(title, isOn: Binding(
            get: { appState.deviceState.touchEnabledFlags & (1 << bit) != 0 },
            set: { value in Task { await appState.setTapEnabled(bit: bit, enabled: value) } }
        ))
    }

}

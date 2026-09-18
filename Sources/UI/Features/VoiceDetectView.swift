// VoiceDetectView.swift
// Voice detection and call settings sheet.

import SwiftUI

struct VoiceDetectSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Detect Conversations", isOn: Binding(
                        get: { appState.deviceState.detectConversations },
                        set: { val in Task { await appState.setDetectConversations(val) } }
                    ))
                    if appState.deviceState.detectConversations {
                        Picker("Duration", selection: Binding(
                            get: { appState.deviceState.detectConversationsDuration },
                            set: { val in Task { await appState.setDetectConversationsDuration(UInt8(val)) } }
                        )) {
                            Text("5s").tag(0)
                            Text("10s").tag(1)
                            Text("15s").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    Text("Switches to Ambient when you speak.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Toggle("Sidetone", isOn: Binding(
                get: { appState.deviceState.sidetoneEnabled },
                set: { val in Task { await appState.setSidetone(val) } }
            ))

            if appState.deviceState.interfaceRevision >= 13 {
                Toggle("Extra clear call sound", isOn: Binding(
                    get: { appState.deviceState.extraClearCallSound },
                    set: { value in Task { await appState.setExtraClearCallSound(value) } }
                ))
            }
            Text("Phone notification reading and Samsung adaptive audio features require the Galaxy Wearable app on a supported phone.")
                .font(.caption).foregroundStyle(.secondary)

        }
        .padding(16)
        .frame(width: 320)
    }
}

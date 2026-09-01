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
                            Text("1s").tag(0)
                            Text("2s").tag(1)
                            Text("3s").tag(2)
                            Text("5s").tag(3)
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

            Toggle("In-Band Ringtone", isOn: Binding(
                get: { appState.deviceState.inBandRingtone },
                set: { val in Task { await appState.setInBandRingtone(val) } }
            ))

            Toggle("Voice Notifications", isOn: Binding(
                get: { appState.deviceState.voiceNotificationEnabled },
                set: { val in Task { await appState.setVoiceNotification(val) } }
            ))

            Toggle("Pause Media on Removal", isOn: Binding(
                get: { appState.deviceState.pauseMediaOnRemoval },
                set: { val in Task { await appState.setPauseMediaOnRemoval(val) } }
            ))

            Toggle("Adaptive Volume", isOn: Binding(
                get: { appState.deviceState.adaptiveVolumeEnabled },
                set: { val in Task { await appState.setAdaptiveVolume(val) } }
            ))
        }
        .padding(16)
        .frame(width: 320)
    }
}

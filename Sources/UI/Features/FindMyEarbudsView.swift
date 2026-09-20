import SwiftUI

struct FindMyEarbudsSheet: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        BudsPage {
            BudsCard(title: "Find nearby earbuds", symbol: "magnifyingglass") {
                Text("Plays a sound on both earbuds. If you're wearing them, a quieter sound plays instead.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button {
                        Task { await appState.startFindMyEarbuds() }
                    } label: {
                        Label("Start ringing", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.deviceState.findMyActive)

                    Button("Stop") {
                        Task { await appState.stopFindMyEarbuds() }
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }

            if appState.deviceState.findMyActive {
                BudsCard(title: "Mute individually", symbol: "speaker.slash") {
                    Toggle("Left earbud", isOn: Binding(
                        get: { appState.deviceState.findMyLeftMuted },
                        set: { val in Task { await appState.muteFindMyEarbud(left: val, right: appState.deviceState.findMyRightMuted) } }
                    ))
                    Toggle("Right earbud", isOn: Binding(
                        get: { appState.deviceState.findMyRightMuted },
                        set: { val in Task { await appState.muteFindMyEarbud(left: appState.deviceState.findMyLeftMuted, right: val) } }
                    ))
                }
            }
        }
        .onDisappear {
            if appState.deviceState.findMyActive { Task { await appState.stopFindMyEarbuds() } }
        }
    }
}

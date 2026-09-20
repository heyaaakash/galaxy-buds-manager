import SwiftUI

struct FitTestSheet: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        BudsPage {
            BudsCard(title: "Earbud fit test", symbol: "ear.badge.checkmark") {
                Text("Check the seal of both earbuds while wearing them.")
                    .font(.caption).foregroundStyle(.secondary)

                if appState.deviceState.fitTestRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Checking seal…").font(.system(size: 12))
                        Spacer()
                        Button("Cancel") { Task { await appState.stopFitTest() } }
                            .controlSize(.small)
                    }
                } else {
                    Button("Start fit test") {
                        Task { await appState.startFitTest() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    if appState.deviceState.wearingLeft != .wearing || appState.deviceState.wearingRight != .wearing {
                        Label("Wear both earbuds for an accurate result.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let result = appState.deviceState.fitTestResult {
                    Divider()
                    Label(
                        result.description,
                        systemImage: result == .passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(result == .passed ? .green : .orange)
                }
            }

            BudsCard(title: "For a better seal", symbol: "lightbulb") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wear both earbuds in a quiet place.")
                    Text("Try a different ear tip size.")
                    Text("Adjust each earbud until the test passes.")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            if appState.deviceState.fitTestRunning { Task { await appState.stopFitTest() } }
        }
    }
}

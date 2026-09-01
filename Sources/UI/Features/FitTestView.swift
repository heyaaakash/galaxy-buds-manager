// FitTestView.swift
// Earbud fit/seal test sheet.

import SwiftUI

struct FitTestSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fit Test").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.bordered).controlSize(.small)
            }

            Text("Checks the seal of each earbud in your ear.")
                .font(.caption).foregroundStyle(.secondary)

            Button("Start Fit Test") {
                Task { await appState.startFitTest() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            if let result = appState.deviceState.fitTestResult {
                Divider()
                HStack {
                    Image(systemName: result == .passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(result == .passed ? .green : .orange)
                    Text(result.description).fontWeight(.medium)
                }
            }

            Divider()

            Text("Tips for a good seal:")
                .font(.system(size: 11, weight: .medium))
            VStack(alignment: .leading, spacing: 4) {
                Text("• Wear both earbuds in a quiet environment")
                Text("• Ensure the correct ear tip size")
                Text("• Adjust position until the test passes")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }
}

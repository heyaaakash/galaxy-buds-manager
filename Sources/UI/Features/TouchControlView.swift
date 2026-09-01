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

            Divider()

            Text("Long Press — Left").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            ForEach(TouchAction.allCases, id: \.rawValue) { action in
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
            ForEach(TouchAction.allCases, id: \.rawValue) { action in
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
}

import SwiftUI

struct TouchControlSheet: View {
    @EnvironmentObject var appState: AppState

    private let longPressActions: [TouchAction] = [
        .voiceAssistant, .noiseControl, .volume, .spotifySpotOn
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Touch surface", symbol: "hand.tap")
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Lock touch controls", isOn: Binding(
                        get: { appState.deviceState.touchpadLocked },
                        set: { val in Task { await appState.setTouchpadLocked(val) } }
                    ))
                    Toggle("Double tap edge for volume", isOn: Binding(
                        get: { appState.deviceState.doubleTapVolume },
                        set: { value in Task { await appState.setDoubleTapVolume(value) } }
                    ))
                }
                .padding(.bottom, 8)

                Divider()
                    .padding(.vertical, 8)

                sectionHeader("Allowed gestures", symbol: "hand.point.up.left")
                VStack(alignment: .leading, spacing: 5) {
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
                .padding(.bottom, 8)

                Divider()
                    .padding(.vertical, 8)

                sectionHeader("Touch and hold actions", symbol: "hand.point.up.left.fill")
                VStack(alignment: .leading, spacing: 5) {
                    Picker("Left earbud", selection: Binding(
                        get: { appState.deviceState.touchLeftAction },
                        set: { action in
                            Task { await appState.setTouchActions(left: action, right: appState.deviceState.touchRightAction) }
                        }
                    )) {
                        ForEach(longPressActions, id: \.rawValue) { action in
                            Text(action.description).tag(action)
                        }
                        if !longPressActions.contains(appState.deviceState.touchLeftAction) {
                            Text("Current: \(appState.deviceState.touchLeftAction.description)")
                                .tag(appState.deviceState.touchLeftAction)
                                .disabled(true)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Picker("Right earbud", selection: Binding(
                        get: { appState.deviceState.touchRightAction },
                        set: { action in
                            Task { await appState.setTouchActions(left: appState.deviceState.touchLeftAction, right: action) }
                        }
                    )) {
                        ForEach(longPressActions, id: \.rawValue) { action in
                            Text(action.description).tag(action)
                        }
                        if !longPressActions.contains(appState.deviceState.touchRightAction) {
                            Text("Current: \(appState.deviceState.touchRightAction.description)")
                                .tag(appState.deviceState.touchRightAction)
                                .disabled(true)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }
            .font(.system(size: 12))
            .controlSize(.small)
            .padding(12)
            .frame(width: BudsUI.width - 20, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Text("Spotify and voice assistant actions depend on the connected phone or Mac app.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, 7)
                .padding(.bottom, 10)
                .frame(width: BudsUI.width, alignment: .leading)
        }
        .frame(width: BudsUI.width, alignment: .leading)
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 7)
    }

    private func tapToggle(_ title: String, bit: UInt8) -> some View {
        Toggle(title, isOn: Binding(
            get: { appState.deviceState.touchEnabledFlags & (1 << bit) != 0 },
            set: { value in Task { await appState.setTapEnabled(bit: bit, enabled: value) } }
        ))
    }
}

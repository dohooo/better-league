import SwiftUI

struct ControlView: View {
    @ObservedObject var model: GuardModel
    @ObservedObject var wifi: WifiModel
    private let accent = Color(red: 0.27, green: 0.66, blue: 0.53)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 26, height: 26)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text("Better League")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())

            SwitchRow(title: "Cursor recovery", status: model.status, tint: accent, identifier: "recovery-toggle",
                      isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) })) {
                if model.needsAccessibility {
                    Button("Open Accessibility Settings", action: model.openAccessibilitySettings)
                }
            }

            Divider()

            SwitchRow(title: "Low-latency Wi-Fi", status: wifi.status, tint: accent, identifier: "wifi-toggle",
                      isOn: Binding(get: { wifi.isEnabled }, set: { wifi.setEnabled($0) })) {
                if wifi.needsHelper {
                    Button("Authorize Network Helper", action: wifi.installHelper)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Divider()
                Text("Runs in the menu bar. Quit from the icon.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

private struct SwitchRow<Action: View>: View {
    let title: String
    let status: String
    let tint: Color
    let identifier: String
    let isOn: Binding<Bool>
    let action: Action

    init(title: String, status: String, tint: Color, identifier: String, isOn: Binding<Bool>, @ViewBuilder action: () -> Action) {
        self.title = title
        self.status = status
        self.tint = tint
        self.identifier = identifier
        self.isOn = isOn
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15))
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .tint(tint)
                    .fixedSize()
                    .accessibilityIdentifier(identifier)
            }
            action
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.glass)
        }
    }
}

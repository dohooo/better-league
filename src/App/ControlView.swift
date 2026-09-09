import SwiftUI

struct ControlView: View {
    @ObservedObject var model: GuardModel
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

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cursor recovery")
                            .font(.system(size: 15))
                        Text(model.status)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Toggle("Cursor recovery", isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.large)
                        .tint(accent)
                        .fixedSize()
                        .accessibilityIdentifier("recovery-toggle")
                }
                if model.needsAccessibility {
                    Button("Open Accessibility Settings", action: model.openAccessibilitySettings)
                        .font(.system(size: 11, weight: .medium))
                        .buttonStyle(.glass)
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
        .padding(2)
    }
}

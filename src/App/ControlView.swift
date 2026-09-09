import SwiftUI

struct ControlView: View {
    @ObservedObject var model: GuardModel
    @Environment(\.colorScheme) private var colorScheme
    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.49, green: 0.76, blue: 0.63) : Color(red: 0.18, green: 0.43, blue: 0.34)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Better League")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Keep your game cursor visible.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cursor recovery")
                            .font(.system(size: 14, weight: .medium))
                        HStack(spacing: 5) {
                            Circle().fill(model.isEnabled ? accent : Color.secondary.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(model.isEnabled ? "On" : "Off")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("Cursor recovery", isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(accent)
                        .accessibilityIdentifier("recovery-toggle")
                }

                if model.status != "Recovery is off" {
                    Text(model.status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.needsAccessibility {
                    Button("Open Accessibility Settings", action: model.openAccessibilitySettings)
                        .font(.system(size: 11, weight: .medium))
                        .buttonStyle(.link)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.06)))

            Text("Lives in the menu bar. Close this window anytime.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

import SwiftUI

struct BubbleActionButton: View {
    @Environment(\.isEnabled) private var isEnabled

    let systemImage: String
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.4))
                .padding(13)
                .circularLiquidGlass(background, isInteractive: isEnabled)
        }
        .buttonStyle(.plain)
        .contentShape(.circle)
    }
}

extension BubbleActionButton {
    static func send(action: @escaping () -> Void) -> BubbleActionButton {
        BubbleActionButton(
            systemImage: "arrow.up",
            background: Color(hex: "FFF4C7"),
            foreground: Color(hex: "9A7600"),
            action: action
        )
    }

    static func stop(action: @escaping () -> Void) -> BubbleActionButton {
        BubbleActionButton(systemImage: "xmark", background: Color(hex: "E14B3C"), foreground: .white, action: action)
    }
}

extension View {
    @ViewBuilder
    func circularLiquidGlass(_ tint: Color, isInteractive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if isInteractive {
                self.glassEffect(.regular.tint(tint.opacity(0.7)).interactive(), in: .circle)
            } else {
                self.glassEffect(.regular.tint(tint.opacity(0.35)), in: .circle)
            }
        } else {
            self
                .background(tint.opacity(isInteractive ? 0.72 : 0.28), in: .circle)
                .background(.ultraThinMaterial, in: .circle)
        }
    }
}

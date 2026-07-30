import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassCard(tint: Color, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.6)), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(tint.opacity(0.6))
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: cornerRadius))
        }
    }
}

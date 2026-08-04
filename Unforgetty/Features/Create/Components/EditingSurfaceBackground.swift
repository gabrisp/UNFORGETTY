import SwiftUI

/// The animated dark radial-glow background `CreateActivityV2View` switches to whenever a card is
/// selected for editing — extracted out so onboarding's "create your first activity" step (which
/// reuses the real editor sheet, not a mock) can show the exact same background instead of a flat
/// placeholder color. `containerSize` drives the glow circles' size, same as the real screen's
/// `editViewModel.geometry.containerSize`.
struct EditingSurfaceBackground: View {
    let style: ActivityStyle
    let containerSize: CGSize

    var body: some View {
        Color.black
            .overlay(alignment: .topTrailing) { backgroundGlow }
            .overlay(alignment: .bottomLeading) { bottomBackgroundGlow }
            .ignoresSafeArea()
    }

    private var backgroundGlow: some View {
        Circle()
            .fill(backgroundGlowGradient)
            .frame(width: backgroundGlowSize, height: backgroundGlowSize)
            .blur(radius: 132)
            .opacity(0.82)
            .offset(x: backgroundGlowSize * 0.36, y: -backgroundGlowSize * 0.46)
            .allowsHitTesting(false)
            .animation(.snappy, value: style.backgroundHex)
            .animation(.snappy, value: style.gradientStartHex)
            .animation(.snappy, value: style.gradientEndHex)
    }

    private var bottomBackgroundGlow: some View {
        Circle()
            .fill(bottomBackgroundGlowGradient)
            .frame(width: bottomBackgroundGlowSize, height: bottomBackgroundGlowSize)
            .blur(radius: 150)
            .opacity(0.46)
            .offset(x: -bottomBackgroundGlowSize * 0.3, y: bottomBackgroundGlowSize * 0.34)
            .allowsHitTesting(false)
            .animation(.snappy, value: style.backgroundHex)
            .animation(.snappy, value: style.gradientStartHex)
            .animation(.snappy, value: style.gradientEndHex)
            .animation(.snappy, value: style.textHex)
    }

    private var backgroundGlowGradient: RadialGradient {
        RadialGradient(
            colors: [
                backgroundGlowColor.opacity(0.95),
                backgroundGlowColor.opacity(0.42),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: backgroundGlowSize * 0.5
        )
    }

    private var bottomBackgroundGlowGradient: RadialGradient {
        RadialGradient(
            colors: [
                bottomBackgroundGlowColor.opacity(0.9),
                bottomBackgroundGlowColor.opacity(0.34),
                .clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: bottomBackgroundGlowSize * 0.5
        )
    }

    private var backgroundGlowColor: Color {
        switch style.backgroundMode {
        case .plain, .image:
            Color(hex: style.backgroundHex)
        case .gradient:
            Color(hex: style.gradientStartHex)
        }
    }

    private var bottomBackgroundGlowColor: Color {
        switch style.backgroundMode {
        case .gradient:
            Color(hex: style.gradientEndHex)
        case .plain, .image:
            Color(hex: style.textHex)
        }
    }

    private var backgroundGlowSize: CGFloat {
        max(700, containerSize.width * 1.72)
    }

    private var bottomBackgroundGlowSize: CGFloat {
        max(640, containerSize.width * 1.58)
    }
}

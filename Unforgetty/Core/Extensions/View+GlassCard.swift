import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension View {
    @ViewBuilder
    func liquidGlassCard(tint: Color, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(tint)
                .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func activityCardBackground(style: ActivityStyle, kind: ActivityKind, cornerRadius: CGFloat) -> some View {
        switch style.backgroundMode {
        case .plain:
            liquidGlassCard(tint: Color(hex: style.backgroundHex), cornerRadius: cornerRadius)
                .innerActivityBorder(style: style, cornerRadius: cornerRadius)
        case .gradient:
            background {
                activityGradient(style: style)
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .innerActivityBorder(style: style, cornerRadius: cornerRadius)
        case .image:
            if kind == .note, let image = backgroundImage(from: style.backgroundImageData) {
                background {
                    image
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
                .innerActivityBorder(style: style, cornerRadius: cornerRadius)
            } else {
                liquidGlassCard(tint: Color(hex: style.backgroundHex), cornerRadius: cornerRadius)
                    .innerActivityBorder(style: style, cornerRadius: cornerRadius)
            }
        }
    }

    @ViewBuilder
    private func activityGradient(style: ActivityStyle) -> some View {
        let colors = [
            Color(hex: style.gradientStartHex),
            Color(hex: style.gradientEndHex)
        ]
        let center = UnitPoint(
            x: min(1, max(0, style.gradientCenterX)),
            y: min(1, max(0, style.gradientCenterY))
        )

        switch style.gradientKind {
        case .linear:
            LinearGradient(
                colors: colors,
                startPoint: gradientEndpoint(angle: style.gradientAngle + 180),
                endPoint: gradientEndpoint(angle: style.gradientAngle)
            )
        case .radial:
            RadialGradient(
                colors: colors,
                center: center,
                startRadius: 0,
                endRadius: 260
            )
        case .angular:
            AngularGradient(
                colors: colors,
                center: center,
                angle: .degrees(style.gradientAngle)
            )
        }
    }

    private func gradientEndpoint(angle: Double) -> UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(
            x: 0.5 + (cos(radians) * 0.5),
            y: 0.5 + (sin(radians) * 0.5)
        )
    }

    @ViewBuilder
    private func innerActivityBorder(style: ActivityStyle, cornerRadius: CGFloat) -> some View {
        if style.borderWidth > 0 {
            overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(hex: style.borderHex), lineWidth: CGFloat(style.borderWidth))
            }
        } else {
            self
        }
    }

    private func backgroundImage(from data: Data?) -> Image? {
        #if canImport(UIKit)
        guard let data, let uiImage = ImageDecodeCache.image(for: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}

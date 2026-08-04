//
//  OnboardingV2NotificationsiPhoneView.swift
//  Creatinely – Notifications step: solo iPhone mockup (mismo diseño que PermissionOnBoarding).
//

import SwiftUI

/// Solo el iPhone mockup con popup de permiso animado. Título, subtítulo y botón los pone el layout (con blur).
struct OnboardingV2NotificationsiPhoneView: View {
    var iPhoneTint: Color = .gray
    var initialDelay: Double = 0.5

    @State private var showPermissionAnimation = false

    var body: some View {
        iPhoneView(tint: iPhoneTint, showPermissionAnimation: showPermissionAnimation)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                guard !showPermissionAnimation else { return }
                try? await Task.sleep(for: .seconds(initialDelay))
                showPermissionAnimation = true
            }
    }
}

// MARK: - iPhone mockup (402×874, visualEffect scale)

private struct iPhoneView: View {
    let tint: Color
    let showPermissionAnimation: Bool

    var body: some View {
        Rectangle()
            .foregroundStyle(.clear)
            .overlay(alignment: .top) {
                let cornerRadius: CGFloat = 55
                let fill: Color = Color.primary.opacity(0.15)

                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(fill)
                        .overlay(alignment: .top) {
                            HStack(spacing: 8) {
                                Text("9:41")
                                    .padding(.leading, 24)
                                Spacer(minLength: 0)
                                Group {
                                    Image(systemName: "wifi")
                                    Image(systemName: "battery.50percent")
                                }
                                .offset(y: -2)
                            }
                            .font(.system(size: 18))
                            .fontWeight(.medium)
                            .frame(height: 37)
                            .padding(.horizontal, 35)
                            .offset(y: 18)
                        }
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.black)
                                .frame(width: 120, height: 37)
                                .offset(y: 15)
                        }

                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius + 7)
                            .stroke(tint, lineWidth: 12)
                        RoundedRectangle(cornerRadius: cornerRadius + 7)
                            .stroke(.black, lineWidth: 4)
                        RoundedRectangle(cornerRadius: cornerRadius + 3)
                            .stroke(.black, lineWidth: 6)
                            .padding(4)
                    }
                    .padding(-7)

                    if showPermissionAnimation {
                        AnimatedAlertView()
                    }
                }
                .frame(width: 402, height: 874)
            }
            .visualEffect { content, proxy in
                let designSize: CGSize = .init(width: 402, height: 874)
                let currentSize = proxy.size
                let ratioX = currentSize.width / designSize.width
                let ratioY = currentSize.height / designSize.height
                let ratio = min(ratioX, ratioY)
                return content.scaleEffect(ratio, anchor: .top)
            }
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Animated permission alert (2 buttons, Allow highlighted)

private struct AnimatedAlertView: View {
    let fill = Color.primary.opacity(0.15)
    private let alertButtons = 2
    private let activeTap = 2

    var body: some View {
        KeyframeAnimator(initialValue: AlertFrame(), repeating: true) { frame in
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(fill)
                    .frame(width: 120, height: 20)
                    .padding(.bottom, 12)

                RoundedRectangle(cornerRadius: 3)
                    .fill(fill)
                    .frame(height: 15)

                RoundedRectangle(cornerRadius: 3)
                    .fill(fill)
                    .frame(height: 15)
                    .padding(.trailing, 50)
                    .padding(.bottom, 30)

                let layout = AnyLayout(HStackLayout(spacing: 8))
                layout {
                    ForEach(1...alertButtons, id: \.self) { index in
                        Capsule()
                            .fill(fill)
                            .frame(height: 45)
                            .overlay {
                                if activeTap == index {
                                    Circle()
                                        .fill(.gray.opacity(0.8))
                                        .padding(5)
                                        .opacity(frame.tapOpacity)
                                }
                            }
                            .scaleEffect(activeTap == index ? frame.tapScale : 1)
                    }
                }
            }
            .frame(width: 280)
            .padding(20)
            .optionalLiquidGlass()
            .opacity(frame.opacity)
            .scaleEffect(frame.scale)
        } keyframes: { _ in
            SpringKeyframe(
                AlertFrame(opacity: 1, scale: 1),
                duration: 0.7,
                spring: .smooth(duration: 0.5, extraBounce: 0)
            )
            SpringKeyframe(
                AlertFrame(opacity: 1, scale: 1, tapOpacity: 1),
                duration: 0.1,
                spring: .smooth(duration: 0.4, extraBounce: 0)
            )
            SpringKeyframe(
                AlertFrame(opacity: 1, scale: 1, tapOpacity: 1, tapScale: 0.9),
                duration: 0.2,
                spring: .smooth(duration: 0.4, extraBounce: 0)
            )
            SpringKeyframe(
                AlertFrame(opacity: 1, scale: 1),
                duration: 0.4,
                spring: .smooth(duration: 0.4, extraBounce: 0)
            )
            SpringKeyframe(
                AlertFrame(),
                duration: 2,
                spring: .smooth(duration: 0.4, extraBounce: 0)
            )
        }
    }
}

@Animatable
private struct AlertFrame {
    var opacity: CGFloat = 0
    var scale: CGFloat = 1.1
    var tapOpacity: CGFloat = 0
    var tapScale: CGFloat = 1
}

private extension View {
    @ViewBuilder
    func optionalLiquidGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.clear, in: .rect(cornerRadius: 30))
        } else {
            self.background {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.background)
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(.gray.opacity(0.4), lineWidth: 1)
                }
            }
        }
    }
}

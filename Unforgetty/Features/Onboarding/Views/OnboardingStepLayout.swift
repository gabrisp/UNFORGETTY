import SwiftUI

/// Shared shape for steps that are just "a title/subtitle plus some content" — extracted so that
/// pattern (previously copy-pasted per step: `Text(title).font(.title.bold())...` etc.) lives in
/// one place. `textAtTop` controls whether the title/subtitle sits above the content (question-style
/// steps, choose-type) or below it (intro/notifications, where the graphic reads first). Steps
/// with nothing resembling a title/subtitle at all (the full-bleed real editor, the paywall with
/// its own complete bottom UI, the welcome step's animated cycling text) don't use this — forcing
/// them through a generic string-based title API would cost more than it'd save.
struct OnboardingStepLayout<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    var textAtTop: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if textAtTop {
                textBlock
                    .padding(.bottom, 24)
                content()
            } else {
                content()
                textBlock
                    .padding(.top, 12)
            }
        }
    }

    private var textBlock: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
    }
}

import SwiftUI

struct OnboardingWelcomeStepView: View {
    // The two things the app actually does — remembering for yourself, and letting someone else
    // know you're thinking of them — alternate as a pair (title+subtitle always change together,
    // one shared index) rather than independently, so they read as one coherent message each time.
    private static let messages: [(title: String, subtitle: String)] = [
        ("Never forget what matters", "Keep the things you can't afford to forget on your Lock Screen."),
        ("Let them know you remember", "Show someone you're thinking of them.")
    ]

    @State private var messageIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            // Clipped to a fixed height, shorter than the marquee's natural 3-row height — this is
            // decorative background context for the headline below, not the focal point, and the
            // full-height marquee (as used in PremiumView, which has no competing text underneath)
            // was squeezing the headline/subtitle down to a truncated single line on smaller
            // screens.
            PaywallMarqueeShowcase()
                .padding(.horizontal, -16)
                .frame(maxWidth: .infinity)
                .padding(.top, -32)
            VStack(spacing: 12) {
                Text(Self.messages[messageIndex].title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                Text(Self.messages[messageIndex].subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeInOut(duration: 0.6)) {
                    messageIndex = (messageIndex + 1) % Self.messages.count
                }
            }
        }
    }
}

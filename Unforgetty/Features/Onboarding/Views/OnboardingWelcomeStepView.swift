import SwiftUI

struct OnboardingWelcomeStepView: View {
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
                .frame(height: 320, alignment: .top)
                .clipped()

            VStack(spacing: 12) {
                Text("Never forget what matters")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Keep the things you can't afford to forget on your Lock Screen — and let the people you care about know you're thinking of them.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
        }
    }
}

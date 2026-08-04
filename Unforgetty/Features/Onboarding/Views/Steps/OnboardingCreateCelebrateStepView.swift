import SwiftUI

/// Shown right after `OnboardingCreateEditorStepView`'s continue action actually starts the Live
/// Activity — a bouncing arrow pointing up hints at swiping up to see it on the Lock Screen. No
/// scheduling mention beyond the one caveat: this first activity went live immediately, ahead-of-
/// time scheduling is a Pro feature introduced on the very next (paywall) step.
struct OnboardingCreateCelebrateStepView: View {
    @State private var isBouncing = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chevron.up")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(y: isBouncing ? -10 : 6)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isBouncing)
                .onAppear { isBouncing = true }

            Text("It's live! Congrats! 🎉")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Swipe up to see it on your Lock Screen right now.\nThis one went live immediately — scheduling activities ahead of time is next.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}

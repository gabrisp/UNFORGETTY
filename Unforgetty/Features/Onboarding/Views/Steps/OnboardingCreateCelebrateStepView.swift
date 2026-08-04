import SwiftUI

/// Shown right after `OnboardingCreateEditorStepView`'s Send button actually starts the Live
/// Activity — the card the user just made stays centered on screen (mirroring how the real app's
/// editor leaves the card in place after a successful send), with a bouncing arrow pointing up and
/// the "It's live!" text overlaid on top of it. No scheduling mention beyond the one caveat: this
/// first activity went live immediately, ahead-of-time scheduling is a Pro feature introduced on
/// the very next (paywall) step.
struct OnboardingCreateCelebrateStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    @State private var isBouncing = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.yellow)
                    .offset(y: isBouncing ? -8 : 4)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isBouncing)
                    .onAppear { isBouncing = true }

                Text("It's live! Congrats! 🎉")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Swipe up to see it on your Lock Screen right now.\nThis one went live immediately — scheduling ahead is next.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            ActivityPreviewView(draft: viewModel.draft)
                .padding(.horizontal, 24)
        }
    }
}

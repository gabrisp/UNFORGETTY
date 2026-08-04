import SwiftUI

/// Literally the real editor screen (`CreateActivityV2View`, `isOnboarding: true`) — not a
/// lookalike built from extracted pieces. Same background, same card, same sheet, same send flow.
/// The only thing that differs is the toolbar (see `CreateActivityV2View`'s `isOnboarding`-gated
/// branches): no kind-switcher, no friend-picker, no top Cancel/Send cutout — a single "Send"
/// button where the kind-switcher would normally sit.
struct OnboardingCreateEditorStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    @Binding var isAwaitingContinue: Bool

    var body: some View {
        CreateActivityV2View(
            progress: .constant(0),
            editViewModel: viewModel,
            isOnboarding: true,
            onboardingSendCompleted: { isAwaitingContinue = true }
        )
    }
}

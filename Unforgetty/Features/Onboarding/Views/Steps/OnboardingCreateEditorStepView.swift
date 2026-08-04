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
        // Matches ContentView.swift's own `.ignoresSafeArea(.keyboard)` on this exact view — its
        // real call site is shielded from keyboard-driven layout shifts, so its sheet's
        // presentationDetents (computed from measured container size) never recompute mid-typing.
        // Without this here too, the keyboard shrinks this view's measured geometry the instant
        // you start typing, and the sheet visibly jumps to match — a discrepancy from the real
        // screen, not a pixel-for-pixel copy of it.
        .ignoresSafeArea(.keyboard)
    }
}

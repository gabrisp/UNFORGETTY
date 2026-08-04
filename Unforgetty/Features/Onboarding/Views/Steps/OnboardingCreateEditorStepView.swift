import SwiftUI

/// Reuses the REAL editor sheet (`CreateActivityV2EditSheet`, `isOnboarding: true`) rather than a
/// simplified mock — same component the main app presents when a card is opened, just with
/// scheduling disabled (see that sheet's `isOnboarding` doc comment) and no kind-switcher/friend
/// picker/top cancel-send toolbar, since none of those exist here in the first place — this view
/// builds its own minimal chrome instead of embedding `CreateActivityV2View`'s full toolbar. In
/// their place, a single onboarding-only "Send" button (top-trailing, where the friend/kind menu
/// would normally sit) does the one thing this step needs: create the activity for real.
struct OnboardingCreateEditorStepView: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    /// Fired once the activity has actually been created and the sheet has closed — the parent
    /// advances the shared onboarding step from here rather than through the normal shared footer,
    /// which is hidden for the whole duration of this step.
    var onSent: () -> Void

    @State private var isShowingSheet = false
    @State private var isSending = false

    var body: some View {
        ZStack {
            // The same "dark editing surface" treatment CreateActivityV2View switches to when a
            // card is selected — simplified to a flat animated color here rather than replicating
            // its full radial-glow background, since this step never shows the card grid behind it.
            Color.black.ignoresSafeArea()

            VStack {
                LivePreviewView(viewModel: viewModel)
                    .padding(.horizontal, 24)
                    .overlay(alignment: .topTrailing) {
                        sendButton
                            .padding(.top, 8)
                            .padding(.trailing, 32)
                    }

                Spacer(minLength: 0)
            }
            .padding(.top, 24)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            isShowingSheet = true
        }
        .sheet(isPresented: $isShowingSheet) {
            CreateActivityV2EditSheet(viewModel: viewModel, copiedEditions: .constant(nil), isOnboarding: true)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled)
                .presentationBackground(.clear)
                .interactiveDismissDisabled()
        }
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            HStack(spacing: 6) {
                if isSending {
                    ProgressView().tint(.black)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                    Text("Send").fontWeight(.semibold)
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .liquidGlassCard(tint: .yellow, cornerRadius: 16, interactive: true)
            .opacity(viewModel.draft.isValid && !isSending ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.draft.isValid || isSending)
    }

    private func send() {
        Haptics.medium()
        isSending = true
        Task {
            viewModel.saveDraft(store: store)
            _ = await viewModel.send(store: store)
            isSending = false
            isShowingSheet = false
            onSent()
        }
    }
}

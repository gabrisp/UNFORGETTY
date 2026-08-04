import SwiftUI

/// Reuses the REAL editing surface, not a mock: `EditingSurfaceBackground` (the same animated dark
/// glow `CreateActivityV2View` shows behind a selected card), `SelectedActivityPreview` (the same
/// `LivePreviewView`-backed card), and `CreateActivityV2EditSheet` itself (`isOnboarding: true`).
/// The only thing that's actually different from the real screen is the toolbar: no kind-switcher,
/// no friend-picker, no top Cancel/Send cutout buttons — just a single onboarding-only "Send"
/// button where the real toolbar's trailing items would sit, because none of those other options
/// apply to a first activity being created inside onboarding.
struct OnboardingCreateEditorStepView: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    /// The parent hides the shared header/footer for the whole step — this flips once the
    /// activity is actually sent, so the footer's Continue button reappears in place of the real
    /// screen's own auto-timeout-then-return-to-grid behavior.
    @Binding var isAwaitingContinue: Bool

    @State private var isShowingSheet = false
    @State private var isSending = false
    @State private var hasSent = false
    @State private var containerSize: CGSize = .zero
    @State private var isBouncing = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                SelectedActivityPreview(
                    viewModel: viewModel,
                    selectedLiveActionID: nil,
                    onEditLiveAction: { _ in },
                    onPickSong: { viewModel.editSubSheet = .songPicker },
                    isPickingSong: viewModel.editSubSheet == .songPicker,
                    isLiveActivity: false,
                    onEndLiveActivity: {},
                    showsStatusPill: false
                )
                .padding(.horizontal, 20)

                if hasSent {
                    liveConfirmation
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 0)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !hasSent {
                    ToolbarItem(placement: .topBarTrailing) {
                        sendButton
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
        .background {
            EditingSurfaceBackground(style: viewModel.draft.style, containerSize: containerSize)
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
            .padding(.vertical, 8)
            .liquidGlassCard(tint: .yellow, cornerRadius: 14, interactive: true)
            .opacity(viewModel.draft.isValid && !isSending ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.draft.isValid || isSending)
    }

    // Same moment the real screen marks with `successBottomBanner` after a send, just with
    // onboarding's own copy in place of the real one's dynamic message, and no 5-second
    // auto-timeout back to the grid — the shared Continue button takes over from here instead.
    private var liveConfirmation: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.up")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(y: isBouncing ? -8 : 4)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isBouncing)
                .onAppear { isBouncing = true }
            Text("It's live! Swipe up!!!")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private func send() {
        Haptics.medium()
        isSending = true
        Task {
            viewModel.saveDraft(store: store)
            let didSend = await viewModel.send(store: store)
            isSending = false
            guard didSend else { return }
            withAnimation(.snappy) {
                isShowingSheet = false
                hasSent = true
                isAwaitingContinue = true
            }
        }
    }
}

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var flow: AppFlowViewModel
    @EnvironmentObject private var store: ActivityStore
    @StateObject private var viewModel = OnboardingViewModel()
    // Owned here (not per-step) so the draft the user builds in `.createFirst` survives a trip
    // back to an earlier step via the back button, and so `.saveDraft(store:)`/`.send(store:)`
    // are only ever called against one consistent instance.
    @StateObject private var editViewModel = CreateActivityV2EditViewModel()
    @State private var isCreatingFirstActivity = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 0)

            stepContent
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .id(viewModel.currentStep)

            Spacer(minLength: 0)

            if viewModel.currentStep != .paywall {
                footer
            }
        }
        .animation(.snappy, value: viewModel.currentStep)
        .onChange(of: viewModel.hasFinishedOnboarding) { _, finished in
            if finished { flow.showRoot() }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            OnboardingWelcomeStepView()
        case .questionForgot:
            OnboardingQuestionStepView(
                question: "How many times have you forgotten to do something important?",
                answer: $viewModel.forgotAnswer
            )
        case .questionRemembered:
            OnboardingQuestionStepView(
                question: "How many times have you thought of someone and wished you'd sent them a nice message?",
                answer: $viewModel.rememberedAnswer
            )
        case .notifications:
            OnboardingNotificationsStepView()
        case .createFirst:
            OnboardingCreateStepView(viewModel: editViewModel)
        case .paywall:
            OnboardingPaywallStepView(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep != .welcome {
                Button {
                    Haptics.light()
                    viewModel.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            OnboardingProgressBar(currentStep: viewModel.currentStep)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var footer: some View {
        Button {
            advance()
        } label: {
            Group {
                if isCreatingFirstActivity {
                    ProgressView().tint(.white)
                } else {
                    Text(continueTitle).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canGoNext || isCreatingFirstActivity)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    private var continueTitle: String {
        switch viewModel.currentStep {
        case .welcome: "Get Started"
        case .notifications: "Enable Notifications"
        case .createFirst: "Continue"
        case .questionForgot, .questionRemembered, .paywall: "Continue"
        }
    }

    private func advance() {
        switch viewModel.currentStep {
        case .notifications:
            Task {
                await OnboardingNotificationPermission.request()
                viewModel.goNext()
            }
        case .createFirst:
            guard editViewModel.draft.isValid else { viewModel.goNext(); return }
            isCreatingFirstActivity = true
            Task {
                editViewModel.saveDraft(store: store)
                _ = await editViewModel.send(store: store)
                isCreatingFirstActivity = false
                viewModel.goNext()
            }
        default:
            Haptics.light()
            viewModel.goNext()
        }
    }
}

private struct OnboardingProgressBar: View {
    let currentStep: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }
}

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var flow: AppFlowViewModel
    @StateObject private var viewModel = OnboardingViewModel()
    // Owned here (not per-step) so the draft the user builds in `.createFirst` survives a trip
    // back to an earlier step via the back button, and so `.saveDraft(store:)`/`.send(store:)`
    // are only ever called against one consistent instance.
    @StateObject private var editViewModel = CreateActivityV2EditViewModel()
    // Flips once OnboardingCreateEditorStepView actually sends the activity — the footer stays
    // hidden for the rest of that step (see `hidesFooter`) until then.
    @State private var isEditorAwaitingContinue = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .opacity(hidesChrome ? 0 : 1)

            Spacer(minLength: 0)

            stepContent
                .transition(.blurReplace)
                .id(viewModel.currentStep)

            Spacer(minLength: 0)

            // .paywall supplies its own complete bottom purchase UI, so the footer is fully
            // removed there (no adjacent layout to keep stable against). .createEditor is
            // different: it's a full-bleed takeover of the real editor sheet — "everything fades
            // to opacity 0" per spec — so it's hidden via opacity like the header, not removed,
            // and disabled so it isn't a hidden tap target, until the activity is actually sent
            // (isEditorAwaitingContinue), at which point the Continue button reappears in place
            // of the real screen's own auto-timeout-then-return-to-grid behavior.
            if viewModel.currentStep != .paywall {
                footer
                    .opacity(hidesChrome ? 0 : 1)
                    .disabled(hidesChrome)
            }
        }
        .animation(.snappy, value: viewModel.currentStep)
        .animation(.snappy, value: isEditorAwaitingContinue)
        .onChange(of: viewModel.currentStep) { _, _ in
            isEditorAwaitingContinue = false
        }
        .onChange(of: viewModel.hasFinishedOnboarding) { _, finished in
            if finished { flow.showRoot() }
        }
    }

    private var hidesChrome: Bool {
        viewModel.currentStep == .createEditor && !isEditorAwaitingContinue
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
        case .createIntro:
            OnboardingCreateIntroStepView()
        case .createChooseType:
            OnboardingCreateChooseTypeStepView(viewModel: editViewModel)
        case .createEditor:
            OnboardingCreateEditorStepView(viewModel: editViewModel, isAwaitingContinue: $isEditorAwaitingContinue)
        case .paywall:
            OnboardingPaywallStepView(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Always laid out (never `if`-removed) so it keeps claiming its space on the
            // .welcome step too — conditionally removing it shifted the progress bar's width
            // each time the back button appeared/disappeared. Hidden with opacity instead, and
            // disabled so it isn't a hidden tap target while invisible.
            Button {
                Haptics.light()
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .liquidGlassCard(tint: Color.secondary.opacity(0.15), cornerRadius: 18, interactive: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(viewModel.currentStep == .welcome ? 0 : 1)
            .disabled(viewModel.currentStep == .welcome)

            OnboardingProgressBar(currentStep: viewModel.currentStep)
                .opacity(viewModel.currentStep == .welcome ? 0 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var footer: some View {
        let isDisabled = !viewModel.canGoNext
        return Button {
            advance()
        } label: {
            Text(continueTitle)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .liquidGlassCard(tint: .yellow, cornerRadius: 20, interactive: true)
            .opacity(isDisabled ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    private var continueTitle: String {
        switch viewModel.currentStep {
        case .welcome: "Get Started"
        case .notifications: "Enable Notifications"
        // .createEditor's footer stays hidden until the activity is actually sent (see
        // hidesChrome) — "Continue" is what it shows once it reappears at that point.
        case .questionForgot, .questionRemembered, .createIntro, .createChooseType, .createEditor, .paywall: "Continue"
        }
    }

    private func advance() {
        switch viewModel.currentStep {
        case .notifications:
            Task {
                await OnboardingNotificationPermission.request()
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
                    .fill(step.rawValue <= currentStep.rawValue ? Color.yellow : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }
}

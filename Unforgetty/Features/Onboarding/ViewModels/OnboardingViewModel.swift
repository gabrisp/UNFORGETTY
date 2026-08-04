import Foundation
import Combine

/// Ordered, in the exact sequence the user steps through them — `OnboardingView` switches on this
/// and the shared progress bar fills proportionally to `rawValue`.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case questionForgot
    case questionRemembered
    case notifications
    // "Create your first activity" is broken into its own mini sequence rather than one crowded
    // screen: an interstitial, then choose-type (with a live example), then customize, then the
    // real content editor — each gets the user's full attention instead of competing for it.
    case createIntro
    case createChooseType
    case createCustomize
    // Sends for real (an immediate, one-off start — no scheduling ahead until the user unlocks
    // Pro on the paywall step right after this) and, once sent, shows "It's live!" + the shared
    // Continue button in place of the sheet, still on this same step — no separate celebrate step.
    case createEditor
    case paywall
}

enum OnboardingAnswer: String, CaseIterable, Identifiable {
    case never
    case sometimes
    case often
    case allTheTime

    var id: Self { self }

    var title: String {
        switch self {
        case .never: "Never"
        case .sometimes: "Once in a while"
        case .often: "More than I'd like"
        case .allTheTime: "All the time"
        }
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    // Mirrors RecentFriendRecipients' shape (CreateActivityV2EditViewModel.swift) — a versioned,
    // device-local UserDefaults key, not App Group storage, since this only needs to survive the
    // app being killed mid-onboarding, not sync anywhere.
    private static let stepKey = "onboardingCurrentStep.v1"
    // Read directly by AppFlowViewModel.bootstrap(store:) — keep this exact string in sync with
    // AppFlow.swift if it's ever renamed.
    private static let finishedKey = "hasFinishedOnboarding"

    @Published var currentStep: OnboardingStep {
        didSet {
            UserDefaults.standard.set(currentStep.rawValue, forKey: Self.stepKey)
        }
    }
    @Published private(set) var hasFinishedOnboarding = false
    @Published var forgotAnswer: OnboardingAnswer?
    @Published var rememberedAnswer: OnboardingAnswer?

    init() {
        let savedRaw = UserDefaults.standard.integer(forKey: Self.stepKey)
        currentStep = OnboardingStep(rawValue: savedRaw) ?? .welcome
    }

    var canGoNext: Bool {
        switch currentStep {
        case .welcome: true
        case .questionForgot: forgotAnswer != nil
        case .questionRemembered: rememberedAnswer != nil
        case .notifications: true
        case .createIntro, .createChooseType, .createCustomize, .createEditor: true
        case .paywall: true
        }
    }

    func goBack() {
        guard let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func goNext() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            finishOnboarding()
            return
        }
        currentStep = next
    }

    func finishOnboarding() {
        guard !hasFinishedOnboarding else { return }
        UserDefaults.standard.set(true, forKey: Self.finishedKey)
        hasFinishedOnboarding = true
    }
}

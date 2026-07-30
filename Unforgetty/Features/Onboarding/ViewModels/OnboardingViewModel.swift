import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var hasFinishedOnboarding = false

    func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasFinishedOnboarding")
        hasFinishedOnboarding = true
    }
}

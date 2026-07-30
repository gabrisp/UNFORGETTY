import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var flow: AppFlowViewModel
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        OnboardingStep1View(viewModel: viewModel)
            .onChange(of: viewModel.hasFinishedOnboarding) { _, finished in
                if finished { flow.showRoot() }
            }
    }
}

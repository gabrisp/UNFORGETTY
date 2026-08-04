import SwiftUI

struct OnboardingCreateCustomizeStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Make it yours")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                ActivityPreviewView(draft: viewModel.draft)
                    .padding(.horizontal, 24)

                StyleEditorView(viewModel: viewModel)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 12)
        }
    }
}

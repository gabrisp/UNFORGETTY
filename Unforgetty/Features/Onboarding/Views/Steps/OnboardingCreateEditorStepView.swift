import SwiftUI

/// The real, interactive editing surface — text typed here goes directly into
/// `viewModel.draft` via `LivePreviewView`, the same component the main app's editor uses.
struct OnboardingCreateEditorStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Add your content")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            LivePreviewView(viewModel: viewModel)
                .padding(.horizontal, 24)
        }
    }
}

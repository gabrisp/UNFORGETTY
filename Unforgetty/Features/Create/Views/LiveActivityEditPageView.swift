import SwiftUI

struct LiveActivityEditPageView: View {
    @ObservedObject var viewModel: LiveActivityEditViewModel
    @EnvironmentObject private var store: ActivityStore

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack(spacing: 18) {
                        LivePreviewView(viewModel: viewModel)
                        DraftActionBarView(viewModel: viewModel) {
                            BubbleActionButton.stop {
                                Task { await viewModel.endActivity(store: store) }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { viewModel.showingEditSheet = true } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEditSheet, onDismiss: {
            Task { await viewModel.saveChanges(store: store) }
        }) {
            EditDraftSheetView(viewModel: viewModel)
        }
    }
}

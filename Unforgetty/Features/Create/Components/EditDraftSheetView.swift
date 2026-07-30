import SwiftUI

struct EditDraftSheetView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    StyleEditorView(viewModel: viewModel)
                    TagsEditorView(viewModel: viewModel)
                }
                .padding(18)
            }
            .navigationTitle("Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Hecho", systemImage: "checkmark.circle.fill")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

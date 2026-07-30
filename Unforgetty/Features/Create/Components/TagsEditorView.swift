import SwiftUI

struct TagsEditorView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    @EnvironmentObject private var store: ActivityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Etiquetas").font(.headline)
            if !viewModel.draft.tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(viewModel.draft.tags) { tag in
                            Button(tag.name) { viewModel.removeTag(tag) }
                                .buttonStyle(.bordered)
                                .contentShape(.rect)
                        }
                    }
                }
            }
            HStack {
                TextField("Nueva etiqueta", text: $viewModel.tagName)
                Button("Añadir") { viewModel.addTag(named: viewModel.tagName, store: store) }
                    .contentShape(.rect)
            }
        }
        .padding(.horizontal, 4)
    }
}

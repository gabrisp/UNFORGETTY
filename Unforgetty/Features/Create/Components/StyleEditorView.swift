import SwiftUI

struct StyleEditorView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    @State private var showingStrictInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ColorPicker("Fondo", selection: viewModel.hexBinding(\.backgroundHex))
                ColorPicker("Texto", selection: viewModel.hexBinding(\.textHex))
            }

            Picker("Alineación", selection: $viewModel.draft.style.alignment) {
                ForEach(ActivityStyle.TextAlignmentChoice.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Slider(value: textSizeBinding, in: ActivityStyle.minimumTextSize...ActivityStyle.maximumTextSize, step: 1) {
                    Text("Tamaño")
                } currentValueLabel: {
                    Text("\(Int(textSizeBinding.wrappedValue))")
                }
                FontPickerButton(selection: $viewModel.draft.style.font)
            }

            HStack(spacing: 6) {
                Toggle("Modo estricto", isOn: $viewModel.draft.isStrict)
                Button { showingStrictInfo = true } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(.circle)
                .popover(isPresented: $showingStrictInfo) {
                    Text("Con el modo estricto activado no podrás borrar esta actividad deslizando desde la lista de creadas. Para una nota, solo desaparece cuando la marcas como hecha desde la propia actividad en pantalla bloqueada.")
                        .font(.footnote)
                        .padding()
                        .frame(maxWidth: 260)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .onAppear {
            viewModel.draft.style.textSize = textSizeBinding.wrappedValue
        }
    }

    private var textSizeBinding: Binding<Double> {
        Binding {
            min(ActivityStyle.maximumTextSize, max(ActivityStyle.minimumTextSize, viewModel.draft.style.textSize))
        } set: { newValue in
            viewModel.draft.style.textSize = newValue
        }
    }
}

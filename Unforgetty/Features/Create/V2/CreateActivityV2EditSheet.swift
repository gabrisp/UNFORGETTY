import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CreateActivityV2EditSheet: View {
    @EnvironmentObject private var store: ActivityStore
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                activityTypePicker
                StyleEditorView(viewModel: viewModel)
                TagsEditorView(viewModel: viewModel)
                scheduleEditor
            }
            .padding(20)
            .padding(.top, 20)
        }
        .alert("No se ha podido enviar", isPresented: errorBinding) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button {
                    dismissKeyboard()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var activityTypePicker: some View {
        Picker("Tipo", selection: kindBinding) {
            Text("Note").tag(ActivityKind.note)
            Text("To Do").tag(ActivityKind.check(.todoList))
        }
        .pickerStyle(.segmented)
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Programar", isOn: Binding(
                get: { viewModel.isScheduling },
                set: {
                    viewModel.toggleScheduling($0)
                    viewModel.saveDraft(store: store)
                }
            ))

            if viewModel.isScheduling {
                WeekdaySelectorView(selection: viewModel.selectedWeekdays) { weekday in
                    viewModel.toggleWeekday(weekday)
                    viewModel.saveDraft(store: store)
                }

                DatePicker("Hora", selection: Binding(
                    get: { viewModel.scheduleTime },
                    set: {
                        viewModel.scheduleTime = $0
                        viewModel.saveDraft(store: store)
                    }
                ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kindBinding: Binding<ActivityKind> {
        Binding {
            viewModel.draft.kind == .note ? .note : .check(.todoList)
        } set: { newValue in
            viewModel.setKind(newValue == .note ? .note : .check(.todoList))
            viewModel.saveDraft(store: store)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.clearError()
            }
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

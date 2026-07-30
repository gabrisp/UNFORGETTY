import SwiftUI

struct DraftActionBarView<VM: DraftEditingViewModel, Trailing: View>: View {
    @ObservedObject var viewModel: VM
    var showsChecklistMenu = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                actionBarContent
            }
        } else {
            actionBarContent
        }
    }

    private var actionBarContent: some View {
        HStack(spacing: 14) {
//            kindButton(
//                title: ActivityKind.note.title,
//                systemImage: "book.fill",
//                iconWidth: 28,
//                isSelected: viewModel.draft.kind == .note
//            ) {
//                setKind(.note)
//            }

            if showsChecklistMenu {
                checkTypeMenu(
                    title: "Check",
                    systemImage: viewModel.draft.kind.isCheck ? "checklist.checked" : "checklist.unchecked",
                    iconWidth: 34,
                    isSelected: viewModel.draft.kind.isCheck
                )
            }

            Spacer()
            trailing()
        }
    }

    private func checkTypeMenu(title: String, systemImage: String, iconWidth: CGFloat, isSelected: Bool) -> some View {
        Menu {
            Button(ActivityKind.CheckKind.buttons.title) {
                setKind(.check(.buttons))
            }

            Button(ActivityKind.CheckKind.todoList.title) {
                setKind(.check(.todoList))
            }

            Button("None") {
                setKind(.note)
            }
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(13)
                .circularLiquidGlass(Color.white.opacity(0.18))
        }
        .buttonStyle(.plain)
        .contentShape(.circle)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func kindButton(title: String, systemImage: String, iconWidth: CGFloat, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(13)
                .circularLiquidGlass(Color.white.opacity(0.18))
        }
        .buttonStyle(.plain)
        .contentShape(.circle)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func setKind(_ kind: ActivityKind) {
        withAnimation(.snappy) { viewModel.draft.kind = kind }
    }
}

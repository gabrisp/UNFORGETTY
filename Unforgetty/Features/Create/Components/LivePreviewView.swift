import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LivePreviewView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    let onMeasuredHeight: ((CGFloat) -> Void)?
    @State private var noteText = ""
    @State private var checklistText = ""
    private let maxInputLines = 6
    private let liveActivityMaxHeight: CGFloat = 300

    init(viewModel: VM, onMeasuredHeight: ((CGFloat) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onMeasuredHeight = onMeasuredHeight
    }

    var body: some View {
        VStack(alignment: viewModel.draft.style.horizontalAlignment, spacing: 14) {
            if viewModel.draft.kind == .note {
                TextField("Don't forget passport", text: $noteText, axis: .vertical)
                    .font(.system(size: viewModel.draft.style.textSize, weight: .medium, design: viewModel.draft.style.fontDesign))
                    .multilineTextAlignment(viewModel.draft.style.textAlignment)
                    .lineLimit(1...maxInputLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: noteText) {
                        syncNoteText()
                    }
                    .keyboardDismissAccessory {
                        dismissKeyboard()
                    }
            } else {
                editableChecklistLayout
            }
        }
        .foregroundStyle(Color(hex: viewModel.draft.style.textHex))
        .padding(24)
        .fixedSize(horizontal: false, vertical: true)
        .measureLivePreviewHeight(onMeasuredHeight)
        .frame(
            maxWidth: .infinity,
            maxHeight: liveActivityMaxHeight,
            alignment: Alignment(horizontal: viewModel.draft.style.horizontalAlignment, vertical: .top)
        )
        .clipped()
        .contentShape(.rect)
        .liquidGlassCard(tint: Color(hex: viewModel.draft.style.backgroundHex), cornerRadius: 20)
        .animation(.snappy, value: viewModel.draft.checklistItems.count)
        .animation(.snappy, value: viewModel.draft.kind)
        .onAppear {
            loadTextStateFromDraft()
        }
        .onChange(of: viewModel.draft.id) {
            loadTextStateFromDraft()
        }
        .onChange(of: viewModel.draft.kind) {
            loadTextStateFromDraft()
        }
    }

    private var checklistRowHeight: CGFloat {
        max(32, viewModel.draft.style.textSize * 1.22)
    }

    private var checkboxSize: CGFloat {
        min(checklistRowHeight, max(24, viewModel.draft.style.textSize * 1.08))
    }

    @ViewBuilder
    private var editableChecklistLayout: some View {
        let items = editableChecklistItems
        let showsAddButton = viewModel.draft.checklistItems.count < maxInputLines
        let slotCount = items.count + (showsAddButton ? 1 : 0)

        if slotCount > 3 {
            HStack(alignment: .top, spacing: 18) {
                editableChecklistColumn(Array(items.prefix(3)), showsAddButton: showsAddButton && slotCount <= 3)
                editableChecklistColumn(Array(items.dropFirst(3)), showsAddButton: showsAddButton && slotCount > 3)
            }
            .frame(maxWidth: .infinity, alignment: contentAlignment)
        } else {
            editableChecklistColumn(items, showsAddButton: showsAddButton)
                .frame(maxWidth: .infinity, alignment: contentAlignment)
        }
    }

    private var contentAlignment: Alignment {
        Alignment(horizontal: viewModel.draft.style.horizontalAlignment, vertical: .center)
    }

    private var editableChecklistItems: [ChecklistItem] {
        Array(viewModel.draft.checklistItems.prefix(maxInputLines))
    }

    private func editableChecklistColumn(_ items: [ChecklistItem], showsAddButton: Bool) -> some View {
        VStack(alignment: viewModel.draft.style.horizontalAlignment, spacing: 14) {
            ForEach(items) { item in
                editableChecklistRow(item)
            }

            if showsAddButton {
                addChecklistRow()
            }
        }
    }

    private func editableChecklistRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleChecklistItem(item)
            } label: {
                checkbox(isCompleted: item.isCompleted, size: checkboxSize)
                    .frame(height: checklistRowHeight, alignment: .center)
            }
            .buttonStyle(.plain)

            TextField("To Do", text: checklistItemTextBinding(for: item))
                .font(.system(size: viewModel.draft.style.textSize, design: viewModel.draft.style.fontDesign))
                .multilineTextAlignment(viewModel.draft.style.textAlignment)
                .lineLimit(1)
                .onSubmit {
                    appendChecklistItemIfPossible(after: item)
                }
                .keyboardDismissAccessory {
                    dismissKeyboard()
                }

            Button {
                removeChecklistItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.55))
                    .frame(width: 24, height: 24)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.draft.checklistItems.count <= 1)
            .opacity(viewModel.draft.checklistItems.count <= 1 ? 0 : 1)
        }
        .frame(maxWidth: .infinity, alignment: contentAlignment)
        .contentShape(.rect)
    }

    private func addChecklistRow() -> some View {
        Button {
            appendChecklistItem()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: checkboxSize, height: checklistRowHeight)

                Text("To Do")
                    .font(.system(size: viewModel.draft.style.textSize, design: viewModel.draft.style.fontDesign))
                    .lineLimit(1)
                    .multilineTextAlignment(viewModel.draft.style.textAlignment)
                    .opacity(0.45)
            }
            .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.65))
            .frame(maxWidth: .infinity, alignment: contentAlignment)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func loadTextStateFromDraft() {
        noteText = clampedText(viewModel.draft.body)
        checklistText = clampedText(viewModel.draft.checklistItems.map(\.text).joined(separator: "\n"))
    }

    private func syncNoteText() {
        let clamped = clampedText(noteText)
        if noteText != clamped {
            noteText = clamped
        }
        viewModel.draft.body = clamped
    }

    private func syncChecklistText() {
        let clamped = clampedText(checklistText)
        if checklistText != clamped {
            checklistText = clamped
        }

        let lines = splitLines(clamped)
        let previousItems = viewModel.draft.checklistItems

        viewModel.draft.checklistItems = lines.enumerated().map { index, line in
            if previousItems.indices.contains(index) {
                var item = previousItems[index]
                item.text = line
                return item
            }

            return ChecklistItem(text: line)
        }

        if viewModel.draft.checklistItems.isEmpty {
            viewModel.draft.checklistItems = [ChecklistItem(text: "")]
        }
    }

    private func checklistItemTextBinding(for item: ChecklistItem) -> Binding<String> {
        Binding {
            viewModel.draft.checklistItems.first(where: { $0.id == item.id })?.text ?? ""
        } set: { newValue in
            guard let index = viewModel.draft.checklistItems.firstIndex(where: { $0.id == item.id }) else { return }
            viewModel.draft.checklistItems[index].text = newValue.replacingOccurrences(of: "\n", with: "")
            trimChecklistItems()
        }
    }

    private func toggleChecklistItem(_ item: ChecklistItem) {
        guard let index = viewModel.draft.checklistItems.firstIndex(where: { $0.id == item.id }) else { return }
        viewModel.draft.checklistItems[index].isCompleted.toggle()
    }

    private func appendChecklistItemIfPossible(after item: ChecklistItem) {
        guard viewModel.draft.checklistItems.count < maxInputLines else { return }
        guard let index = viewModel.draft.checklistItems.firstIndex(where: { $0.id == item.id }) else { return }
        viewModel.draft.checklistItems.insert(ChecklistItem(text: ""), at: index + 1)
    }

    private func appendChecklistItem() {
        guard viewModel.draft.checklistItems.count < maxInputLines else { return }
        viewModel.draft.checklistItems.append(ChecklistItem(text: ""))
    }

    private func removeChecklistItem(_ item: ChecklistItem) {
        guard viewModel.draft.checklistItems.count > 1 else { return }
        withAnimation(.snappy) {
            viewModel.draft.checklistItems.removeAll { $0.id == item.id }
        }
        trimChecklistItems()
    }

    private func trimChecklistItems() {
        if viewModel.draft.checklistItems.count > maxInputLines {
            viewModel.draft.checklistItems = Array(viewModel.draft.checklistItems.prefix(maxInputLines))
        }
        if viewModel.draft.checklistItems.isEmpty {
            viewModel.draft.checklistItems = [ChecklistItem(text: "")]
        }
    }

    private func clampedText(_ text: String) -> String {
        splitLines(text).joined(separator: "\n")
    }

    private func splitLines(_ text: String) -> [String] {
        Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).prefix(maxInputLines)).map(String.init)
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func checkbox(isCompleted: Bool, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color(hex: viewModel.draft.style.textHex), lineWidth: 2)
                .frame(width: size, height: size)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.66, weight: .bold))
            }
        }
        .contentShape(.rect)
    }
}

private extension View {
    func keyboardDismissAccessory(action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button {
                    action()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .padding(.vertical, 8)
            }
        }
    }

    func measureLivePreviewHeight(_ onMeasuredHeight: ((CGFloat) -> Void)?) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        onMeasuredHeight?(proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        onMeasuredHeight?(newValue)
                    }
            }
        }
    }
}

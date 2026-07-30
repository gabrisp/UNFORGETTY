import SwiftUI

struct LivePreviewView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    let onMeasuredHeight: ((CGFloat) -> Void)?
    @State private var noteText = ""
    @State private var checklistText = ""
    private let maxInputLines = 6

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
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.draft.checklistItems.enumerated()), id: \.element.id) { index, item in
                            Button {
                                guard viewModel.draft.checklistItems.indices.contains(index) else { return }
                                viewModel.draft.checklistItems[index].isCompleted.toggle()
                            } label: {
                                checkbox(isCompleted: item.isCompleted, size: checkboxSize)
                                    .frame(height: checklistRowHeight, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("Tarea", text: $checklistText, axis: .vertical)
                        .font(.system(size: viewModel.draft.style.textSize, design: viewModel.draft.style.fontDesign))
                        .lineLimit(1...maxInputLines)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: checklistText) {
                            syncChecklistText()
                        }
                }
                .contentShape(.rect)
            }
        }
        .foregroundStyle(Color(hex: viewModel.draft.style.textHex))
        .padding(24)
        .fixedSize(horizontal: false, vertical: true)
        .measureLivePreviewHeight(onMeasuredHeight)
        .frame(
            maxWidth: .infinity,
            alignment: Alignment(horizontal: viewModel.draft.style.horizontalAlignment, vertical: .top)
        )
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

    private func clampedText(_ text: String) -> String {
        splitLines(text).joined(separator: "\n")
    }

    private func splitLines(_ text: String) -> [String] {
        Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).prefix(maxInputLines)).map(String.init)
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

import SwiftUI

/// The literal content of an activity — identical between the in-app preview and the real Live Activity.
struct ActivityContentView: View {
    let draft: LiveActivityDraft

    var body: some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
            if draft.kind == .note {
                Text(noteText)
                    .font(.system(size: draft.style.textSize, weight: .medium, design: draft.style.fontDesign))
                    .multilineTextAlignment(draft.style.textAlignment)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
                    .opacity(isNotePlaceholder ? 0.45 : 1)
            } else {
                if displayedChecklistItems.count == 6 {
                    HStack(alignment: .top, spacing: 18) {
                        checklistColumn(Array(displayedChecklistItems.prefix(3)))
                        checklistColumn(Array(displayedChecklistItems.suffix(3)))
                    }
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
                } else {
                    checklistColumn(displayedChecklistItems)
                        .frame(maxWidth: .infinity, alignment: contentAlignment)
                }
            }
        }
        .foregroundStyle(Color(hex: draft.style.textHex))
    }

    private var contentAlignment: Alignment {
        Alignment(horizontal: draft.style.horizontalAlignment, vertical: .center)
    }

    private var noteText: String {
        isNotePlaceholder ? "Note" : draft.body
    }

    private var isNotePlaceholder: Bool {
        draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func checklistText(for item: ChecklistItem) -> String {
        isChecklistPlaceholder(item) ? "To Do" : item.text
    }

    private func isChecklistPlaceholder(_ item: ChecklistItem) -> Bool {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedChecklistItems: [ChecklistItem] {
        Array(draft.checklistItems.prefix(6))
    }

    private func checklistColumn(_ items: [ChecklistItem]) -> some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
            ForEach(items) { item in
                checklistRow(item)
            }
        }
    }

    private func checklistRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 12) {
            checkbox(isCompleted: item.isCompleted)
            Text(checklistText(for: item))
                .font(.system(size: draft.style.textSize, design: draft.style.fontDesign))
                .strikethrough(item.isCompleted)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isChecklistPlaceholder(item) ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity, alignment: contentAlignment)
        .contentShape(.rect)
    }

    private func checkbox(isCompleted: Bool) -> some View {
        let rowHeight = max(32, draft.style.textSize * 1.22)
        let size = min(rowHeight, max(24, draft.style.textSize * 1.08))

        return ZStack {
            Circle()
                .stroke(Color(hex: draft.style.textHex), lineWidth: 2)
                .frame(width: size, height: size)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.66, weight: .bold))
            }
        }
        .contentShape(.rect)
    }
}

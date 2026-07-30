import SwiftUI

@MainActor
protocol DraftEditingViewModel: AnyObject, ObservableObject {
    var draft: LiveActivityDraft { get set }
    var tagName: String { get set }
}

extension DraftEditingViewModel {
    func hexBinding(_ keyPath: WritableKeyPath<ActivityStyle, String>) -> Binding<Color> {
        Binding(get: { Color(hex: self.draft.style[keyPath: keyPath]) }, set: { color in
            guard let components = UIColor(color).cgColor.components else { return }
            let r = Int((components.count > 2 ? components[0] : components[0]) * 255)
            let g = Int((components.count > 2 ? components[1] : components[0]) * 255)
            let b = Int((components.count > 2 ? components[2] : components[0]) * 255)
            self.draft.style[keyPath: keyPath] = String(format: "%02X%02X%02X", r, g, b)
        })
    }

    func addTag(named name: String, store: ActivityStore) {
        let tag = store.makeTag(named: name)
        guard !tag.name.isEmpty else { return }
        withAnimation(.snappy) { draft.tags.append(tag) }
        tagName = ""
    }

    func removeTag(_ tag: Tag) {
        withAnimation(.snappy) { draft.tags.removeAll { $0.id == tag.id } }
    }

    func addChecklistItem() {
        withAnimation(.snappy) { draft.checklistItems.append(ChecklistItem(text: "")) }
    }

    func removeChecklistItem(_ item: ChecklistItem) {
        guard draft.checklistItems.count > 1 else { return }
        withAnimation(.snappy) { draft.checklistItems.removeAll { $0.id == item.id } }
        ensureMinimumChecklistItem()
    }

    func handleChecklistTextChange(after itemID: UUID, text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, draft.checklistItems.count > 1 {
            withAnimation(.snappy) { draft.checklistItems.removeAll { $0.id == itemID } }
            ensureMinimumChecklistItem()
            return
        }

        splitChecklistText(after: itemID, text: text)
    }

    private func ensureMinimumChecklistItem() {
        guard draft.checklistItems.isEmpty else { return }
        draft.checklistItems = [ChecklistItem(text: "")]
    }

    /// Splits pasted multi-line text so each line becomes its own task.
    private func splitChecklistText(after itemID: UUID, text: String) {
        guard let index = draft.checklistItems.firstIndex(where: { $0.id == itemID }) else { return }
        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1 else { return }
        withAnimation(.snappy) {
            draft.checklistItems[index].text = lines[0]
            let newItems = lines
                .dropFirst()
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { ChecklistItem(text: $0) }
            draft.checklistItems.insert(contentsOf: newItems, at: index + 1)
        }
    }
}

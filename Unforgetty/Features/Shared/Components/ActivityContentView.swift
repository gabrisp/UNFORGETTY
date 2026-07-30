import SwiftUI

/// The literal content of an activity — identical between the in-app preview and the real Live Activity.
struct ActivityContentView: View {
    let draft: LiveActivityDraft

    var body: some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
            if draft.kind == .note {
                Text(draft.body)
                    .font(.system(size: draft.style.textSize, weight: .medium, design: draft.style.fontDesign))
                    .multilineTextAlignment(draft.style.textAlignment)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
            } else {
                ForEach(draft.checklistItems) { item in
                    HStack(spacing: 12) {
                        checkbox(isCompleted: item.isCompleted)
                        Text(item.text)
                            .font(.system(size: draft.style.textSize, design: draft.style.fontDesign))
                            .strikethrough(item.isCompleted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
                    .contentShape(.rect)
                }
            }
        }
        .foregroundStyle(Color(hex: draft.style.textHex))
    }

    private var contentAlignment: Alignment {
        Alignment(horizontal: draft.style.horizontalAlignment, vertical: .center)
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

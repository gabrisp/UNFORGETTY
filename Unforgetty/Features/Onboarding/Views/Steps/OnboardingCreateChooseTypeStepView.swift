import SwiftUI

/// Type selection with a live, read-only example underneath — `ActivityPreviewView` re-renders
/// automatically as `viewModel.draft.kind` changes, so picking a different type visibly swaps the
/// example design without letting the user start typing into it yet (that's `OnboardingCreateEditorStepView`).
struct OnboardingCreateChooseTypeStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Choose a type")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("You can always change this later.")
                    .foregroundStyle(.secondary)
            }

            kindPicker

            ActivityPreviewView(draft: viewModel.draft)
                .padding(.horizontal, 24)
        }
    }

    private var kindPicker: some View {
        HStack(spacing: 14) {
            ForEach(ActivityKind.allCases) { kind in
                kindButton(kind)
            }
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.selection, trigger: viewModel.draft.kind)
    }

    private func kindButton(_ kind: ActivityKind) -> some View {
        let isSelected = viewModel.draft.kind == kind
        return Button {
            viewModel.setKind(kind)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbolName(for: kind))
                    .font(.system(size: 18, weight: .semibold))
                Text(kind.title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .liquidGlassCard(tint: isSelected ? Color.yellow.opacity(0.35) : Color.secondary.opacity(0.1), cornerRadius: 14, interactive: true)
            .foregroundStyle(isSelected ? Color.yellow : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func symbolName(for kind: ActivityKind) -> String {
        switch kind {
        case .note: "note.text"
        case .image: "photo"
        case .music: "music.note"
        case .check(.buttons): "square.grid.2x2"
        case .check(.todoList): "checklist"
        }
    }
}

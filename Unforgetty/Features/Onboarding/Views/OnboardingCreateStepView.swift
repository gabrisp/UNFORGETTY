import SwiftUI

/// Lets the user build their first real activity using the same editor components the main app
/// uses (`LivePreviewView`, `StyleEditorView`) — not a mockup — driven by a
/// `CreateActivityV2EditViewModel` the parent `OnboardingView` owns so the draft survives if this
/// step is revisited via the back button.
struct OnboardingCreateStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Create your first reminder")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text("Design something you don't want to forget — we'll bring it to life right on your Lock Screen.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                kindPicker

                LivePreviewView(viewModel: viewModel)
                    .padding(.horizontal, 24)

                StyleEditorView(viewModel: viewModel)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 12)
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
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
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

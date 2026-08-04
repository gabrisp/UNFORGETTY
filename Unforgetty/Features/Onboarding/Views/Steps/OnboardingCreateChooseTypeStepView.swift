import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Type selection with a live, read-only example underneath — re-renders as `viewModel.draft.kind`
/// changes, so picking a different type visibly swaps the example design without letting the user
/// start typing into it yet (that's `OnboardingCreateEditorStepView`). The preview intentionally
/// renders a synthetic `exampleDraft`, NOT `viewModel.draft` itself — the real draft stays blank
/// here so the user's actual first activity doesn't start pre-filled with this placeholder copy
/// once they reach the editor step; only `kind` (set via `setKind`) carries forward.
struct OnboardingCreateChooseTypeStepView: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel

    var body: some View {
        OnboardingStepLayout(title: "Choose a type", subtitle: "You can always change this later.", textAtTop: true) {
            VStack(spacing: 24) {
                kindPicker
                ActivityPreviewView(draft: exampleDraft(for: viewModel.draft.kind))
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)
        }
    }

    private func exampleDraft(for kind: ActivityKind) -> LiveActivityDraft {
        var draft = LiveActivityDraft()
        draft.kind = kind
        switch kind {
        case .note:
            draft.body = "Write anything you want :)"
        case .image:
            // No generic bundled "example photo" asset exists — reusing one of the bundled music
            // preview images as a stand-in still shows a real photo filling the card, which reads
            // better than the bare "no photo yet" placeholder icon.
            #if canImport(UIKit)
            draft.style.backgroundImageData = UIImage(named: "prev_music_1")?.jpegData(compressionQuality: 0.9)
            #endif
        case .music:
            draft.musicTitle = "Your favorite song"
            draft.musicArtist = "Any artist"
            #if canImport(UIKit)
            draft.musicAlbumArtData = UIImage(named: "prev_music_1")?.jpegData(compressionQuality: 0.9)
            #endif
        case .check(.todoList):
            draft.checklistItems = [ChecklistItem(text: "Buy groceries"), ChecklistItem(text: "Call mom")]
        case .check(.buttons):
            break
        }
        return draft
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
            .contentShape(Rectangle())
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

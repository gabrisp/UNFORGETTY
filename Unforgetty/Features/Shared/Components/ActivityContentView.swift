import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The literal content of an activity — identical between the in-app preview and the real Live Activity.
struct ActivityContentView: View {
    let draft: LiveActivityDraft
    var allowsTapBlur = true
    var allowsActions = false
    /// Lets a caller (e.g. the paywall's interactive checklist showcase) make checklist rows
    /// tappable without this shared view owning any mutable state itself — nil everywhere else,
    /// so every other call site (the real Live Activity preview, saved-card list) is unaffected.
    var onToggleChecklistItem: ((UUID) -> Void)?
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var isTapBlurred = true

    var body: some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
            if draft.kind == .note {
                Text(noteText)
                    .font(.system(size: draft.style.textSize, weight: .medium, design: draft.style.fontDesign))
                    .multilineTextAlignment(draft.style.textAlignment)
                    .lineSpacing(draft.style.textSize * draft.style.lineSpacingMultiplier)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                    .opacity(isNotePlaceholder ? 0.45 : 1)
            } else if draft.kind == .image {
                imageContent
            } else if draft.kind == .music {
                musicContent
            } else if draft.kind == .check(.buttons) {
                liveActionsGrid
            } else {
                if displayedChecklistItems.count > 3 {
                    let firstColumnCount = (displayedChecklistItems.count + 1) / 2
                    HStack(alignment: .top, spacing: 16) {
                        checklistColumn(Array(displayedChecklistItems.prefix(firstColumnCount)))
                        checklistColumn(Array(displayedChecklistItems.dropFirst(firstColumnCount)))
                    }
                    .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                } else {
                    checklistColumn(displayedChecklistItems)
                        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
        .foregroundStyle(Color(hex: draft.style.textHex))
        .blur(radius: isContentBlurred ? 10 : 0)
        .contentShape(.rect)
        .tapBlurGesture(isEnabled: allowsTapBlur) {
            toggleTapBlurIfNeeded()
        }
        .animation(.snappy, value: isContentBlurred)
    }

    private var noteText: String {
        isNotePlaceholder ? "Note" : draft.body
    }

    private var isNotePlaceholder: Bool {
        draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var imageContent: some View {
        Group {
            if let image = contentImage {
                image
                    .resizable()
                    .scaledToFill()
                    .offset(y: draft.style.imageOffsetY)
            } else {
                Image(systemName: "photo")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity)
        // Matches ActivityPreviewView's liveActivityMaxHeight(160) minus its own contentPadding —
        // kept in sync manually since this view doesn't know its container's padding.
        .frame(height: 160 - (draft.style.imageInset * 2))
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }

    // Static (no spin) — this view backs the scrollable saved-card list, where several music
    // cards could be on screen at once, and the point of the editor's spin was specifically about
    // that single always-live-editing context.
    private var musicContent: some View {
        HStack(alignment: draft.style.swiftUIVerticalAlignment, spacing: 16) {
            if draft.style.musicArtPosition == .leading {
                musicArtGroup
                musicTextGroup
            } else {
                musicTextGroup
                musicArtGroup
            }
        }
        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
    }

    @ViewBuilder
    private var musicTextGroup: some View {
        if draft.style.musicShowsTitle || draft.style.musicShowsArtist || draft.style.musicShowsAlbum {
            VStack(alignment: .leading, spacing: 4) {
                if draft.style.musicShowsTitle {
                    Text(draft.musicTitle.isEmpty ? "Music" : draft.musicTitle)
                        .font(.system(size: draft.style.textSize * 0.55, weight: .semibold, design: draft.style.fontDesign))
                        .lineLimit(1)
                }
                if draft.style.musicShowsArtist, !draft.musicArtist.isEmpty {
                    Text(draft.musicArtist)
                        .font(.system(size: draft.style.textSize * 0.4, design: draft.style.fontDesign))
                        .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.7))
                        .lineLimit(1)
                }
                if draft.style.musicShowsAlbum, !draft.musicAlbum.isEmpty {
                    Text(draft.musicAlbum)
                        .font(.system(size: draft.style.textSize * 0.34, design: draft.style.fontDesign))
                        .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
    }

    private var musicArtGroup: some View {
        Group {
            if let image = musicAlbumArtImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.55))
                }
            }
        }
        .frame(width: 112, height: 112)
        .clipShape(draft.style.musicLayout.clipShape)
        .overlay {
            if draft.style.musicBorderEnabled {
                draft.style.musicLayout.clipShape.stroke(Color(hex: draft.style.musicBorderHex), lineWidth: 3)
            }
        }
    }

    private var musicAlbumArtImage: Image? {
        #if canImport(UIKit)
        guard let data = draft.musicAlbumArtData, let uiImage = ImageDecodeCache.image(for: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private var contentImage: Image? {
        #if canImport(UIKit)
        guard let data = draft.style.backgroundImageData, let uiImage = ImageDecodeCache.image(for: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private var liveActionGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: liveActionColumnCount)
    }

    private var showsLiveActionTitles: Bool {
        liveActionGridCapacity < 6
    }

    private var liveActionGridCapacity: Int {
        let count = min(draft.liveActionItems.count, 8)
        if count <= 1 { return 1 }
        if count <= 2 { return 2 }
        if count <= 4 { return 4 }
        if count <= 6 { return 6 }
        return 8
    }

    private var liveActionColumnCount: Int {
        liveActionGridCapacity <= 2 ? liveActionGridCapacity : liveActionGridCapacity / 2
    }

    private var liveActionGridHeight: CGFloat {
        136
    }

    // private var liveActionTileHeight: CGFloat {
    //     liveActionGridCapacity <= 2 ? liveActionGridHeight : (liveActionGridHeight - 8) / 2
    // }

    private var liveActionTileHeight: CGFloat { liveActionGridCapacity <= 2 ? liveActionGridHeight : (liveActionGridHeight - 10) / 2 }

    private var liveActionsGrid: some View {
        LazyVGrid(columns: liveActionGridColumns, spacing: 10) {
            ForEach(draft.liveActionItems.prefix(8)) { item in
                if allowsActions, let url = liveActionURL(for: item) {
                    Link(destination: url) {
                        liveActionTile(item)
                    }
                    .buttonStyle(.plain)
                } else {
                    liveActionTile(item)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: liveActionGridHeight, maxHeight: liveActionGridHeight, alignment: .center)
    }

    /// Live action tiles are tiny and fixed-size, so the style's textSize (18–44, tuned for note/
    /// checklist text) can't be used directly — it's scaled relative to its default and clamped,
    /// then the tile clips so an extreme size can't spill outside its frame.
    private var liveActionFontScale: CGFloat {
        draft.style.textSize / ActivityStyle.defaultTextSize
    }

    private func liveActionTile(_ item: LiveActionItem) -> some View {
        HStack(spacing: showsLiveActionTitles ? 7 : 0) {
            liveActionIcon(item)

            if showsLiveActionTitles {
                Text(item.title)
                    .font(.system(size: min(max(10 * liveActionFontScale, 7), 15), weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Color(hex: item.textHex))
        // .padding(.horizontal, showsLiveActionTitles ? 8 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: liveActionTileHeight)
        .background(Color(hex: item.backgroundHex), in: .rect(cornerRadius: 16, style: .continuous))
        .clipped()
    }

    @ViewBuilder
    private func liveActionIcon(_ item: LiveActionItem) -> some View {
        if let emoji = item.customIcon?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty {
            Text(String(emoji.prefix(2)))
                .font(.system(size: min(max((showsLiveActionTitles ? 22 : 26) * liveActionFontScale, 14), 34)))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: item.icon)
                .font(.system(size: min(max((showsLiveActionTitles ? 20 : 24) * liveActionFontScale, 12), 32), weight: .semibold))
                .frame(width: 30, height: 30)
        }
    }

    private func liveActionURL(for item: LiveActionItem) -> URL? {
        LiveActionURLBuilder.url(kind: item.kind.rawValue, target: item.target, shortcutInput: item.shortcutInput)
    }

    private var isContentBlurred: Bool {
        guard allowsTapBlur || draft.blurContentMode != .tapToToggle else { return false }
        switch draft.blurContentMode {
        case .tapToToggle:
            return draft.kind == .note && isTapBlurred
        case .never:
            return false
        case .whenLuminanceReduced:
            return isLuminanceReduced
        }
    }

    private func toggleTapBlurIfNeeded() {
        guard allowsTapBlur else { return }
        guard draft.kind == .note, draft.blurContentMode == .tapToToggle else { return }
        isTapBlurred.toggle()
    }

    private func checklistText(for item: ChecklistItem) -> String {
        isChecklistPlaceholder(item) ? "To Do" : item.text
    }

    private func isChecklistPlaceholder(_ item: ChecklistItem) -> Bool {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedChecklistItems: [ChecklistItem] {
        let items = draft.hideCompletedChecklistItems
            ? draft.checklistItems.filter { !$0.isCompleted }
            : draft.checklistItems
        return Array(items.prefix(6))
    }

    private func checklistColumn(_ items: [ChecklistItem]) -> some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 16) {
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
        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
        .contentShape(.rect)
        .onTapGesture {
            onToggleChecklistItem?(item.id)
        }
    }

    private func checkbox(isCompleted: Bool) -> some View {
        let rowHeight = max(32, draft.style.textSize * 1.22)
        let size = min(rowHeight, max(24, draft.style.textSize * 1.08))
        let scheme = draft.style.checklistScheme

        return ZStack {
            if scheme == .circleCheckPadded {
                Circle()
                    .stroke(Color(hex: draft.style.textHex), lineWidth: 2)
                    .frame(width: size, height: size)
                Circle()
                    .fill(Color(hex: draft.style.textHex))
                    .frame(width: size * 0.56, height: size * 0.56)
                    .opacity(isCompleted ? 1 : 0.22)
            } else if let emptySymbol = scheme.emptySymbol, let completedSymbol = scheme.completedSymbol {
                Image(systemName: isCompleted ? completedSymbol : emptySymbol)
                    .font(.system(size: size * scheme.symbolScale, weight: .semibold))
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .stroke(Color(hex: draft.style.textHex), lineWidth: 2)
                    .frame(width: size * scheme.symbolScale, height: size * scheme.symbolScale)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * scheme.symbolScale * 0.66, weight: .bold))
                }
            }
        }
        .contentShape(.rect)
    }
}

private extension View {
    @ViewBuilder
    func tapBlurGesture(isEnabled: Bool, action: @escaping () -> Void) -> some View {
        if isEnabled {
            onTapGesture(perform: action)
        } else {
            self
        }
    }
}

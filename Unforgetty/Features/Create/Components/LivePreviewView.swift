import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct LivePreviewView<VM: DraftEditingViewModel>: View {
    @ObservedObject var viewModel: VM
    let onMeasuredHeight: ((CGFloat) -> Void)?
    let onEditLiveAction: ((UUID) -> Void)?
    let onPickSong: (() -> Void)?
    /// Whether the song-picker sheet is currently open — the music art's white outline only shows
    /// while that's true, not just because this content happens to be music.
    let isEditingMusic: Bool
    let selectedLiveActionID: UUID?
    @State private var noteText = ""
    @State private var checklistText = ""
    @FocusState private var focusedField: Field?
    @State private var isShowingImagePicker = false
    @State private var backgroundImageSelection: PhotosPickerItem?
    @State private var imageDragStartOffsetY: Double?
    private let maxInputLines = 6
    private let liveActivityMaxHeight: CGFloat = 160

    init(
        viewModel: VM,
        onMeasuredHeight: ((CGFloat) -> Void)? = nil,
        selectedLiveActionID: UUID? = nil,
        onEditLiveAction: ((UUID) -> Void)? = nil,
        onPickSong: (() -> Void)? = nil,
        isEditingMusic: Bool = false
    ) {
        self.viewModel = viewModel
        self.onMeasuredHeight = onMeasuredHeight
        self.selectedLiveActionID = selectedLiveActionID
        self.onEditLiveAction = onEditLiveAction
        self.onPickSong = onPickSong
        self.isEditingMusic = isEditingMusic
    }

    var body: some View {
        VStack(alignment: viewModel.draft.style.horizontalAlignment, spacing: 14) {
            if viewModel.draft.kind == .note {
                TextField("Note", text: noteTextBinding, axis: .vertical)
                    .font(.system(size: viewModel.draft.style.textSize, weight: .medium, design: viewModel.draft.style.fontDesign))
                    .multilineTextAlignment(viewModel.draft.style.textAlignment)
                    .lineLimit(1...maxInputLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: viewModel.draft.style.contentAlignment)
                    .focused($focusedField, equals: .note)
                    .onChange(of: noteText) {
                        syncNoteText()
                    }
            } else if viewModel.draft.kind == .image {
                editableImageContent
            } else if viewModel.draft.kind == .music {
                editableMusicContent
            } else if viewModel.draft.kind == .check(.buttons) {
                editableLiveActionsGrid
            } else {
                editableChecklistLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: viewModel.draft.style.contentAlignment)
        .foregroundStyle(Color(hex: viewModel.draft.style.textHex))
        .padding(contentPadding)
        .fixedSize(horizontal: false, vertical: true)
        .measureLivePreviewHeight(onMeasuredHeight)
        .frame(
            maxWidth: .infinity,
            maxHeight: liveActivityMaxHeight,
            alignment: viewModel.draft.style.contentAlignment
        )
        .clipped()
        .contentShape(.rect)
        .activityCardBackground(style: viewModel.draft.style, kind: viewModel.draft.kind, cornerRadius: 20)
        .animation(.snappy, value: viewModel.draft.checklistItems.count)
        .animation(.snappy, value: viewModel.draft.kind)
        .sensoryFeedback(.selection, trigger: selectedLiveActionID)
        .sensoryFeedback(.selection, trigger: viewModel.draft.liveActionItems.count)
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
        min(40, max(32, viewModel.draft.style.textSize * 1.22))
    }

    // Matches ActivityContentView/UnforgettyWidget exactly — todoList used to get 0 here (from
    // when rows carried their own background pill padding), which no longer applies now that
    // rows are bare, and it made the editor's margins not match the real content's.
    private var contentPadding: CGFloat {
        switch viewModel.draft.kind {
        case .check(.buttons): 12
        case .image: viewModel.draft.style.imageInset
        case .music: 24
        default: 24
        }
    }

    private var checkboxSize: CGFloat {
        min(checklistRowHeight, max(24, viewModel.draft.style.textSize * 1.08))
    }

    private var liveActionGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: liveActionColumnCount)
    }

    private var showsLiveActionTitles: Bool {
        liveActionGridCapacity < 6
    }

    private var liveActionGridCapacity: Int {
        let count = min(viewModel.draft.liveActionItems.count, 8)
        if count <= 1 { return 1 }
        if count <= 2 { return 2 }
        if count <= 4 { return 4 }
        if count <= 6 { return 6 }
        return 8
    }

    private var liveActionColumnCount: Int {
        liveActionGridCapacity <= 2 ? liveActionGridCapacity : liveActionGridCapacity / 2
    }

    // private var liveActionGridHeight: CGFloat {
    //     liveActivityMaxHeight - (contentPadding * 2)
    // }

    private var liveActionGridHeight: CGFloat { liveActivityMaxHeight - (contentPadding * 2) }

    // private var liveActionTileHeight: CGFloat {
    //     liveActionGridCapacity <= 2 ? liveActionGridHeight : (liveActionGridHeight - 8) / 2
    // }

    private var liveActionTileHeight: CGFloat { liveActionGridCapacity <= 2 ? liveActionGridHeight : (liveActionGridHeight - 10) / 2 }

    private var liveActionTileCornerRadius: CGFloat {
        16
    }

    private var editableImageContent: some View {
        Group {
            if let image = contentImage {
                image
                    .resizable()
                    .scaledToFill()
                    .offset(y: viewModel.draft.style.imageOffsetY)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2.weight(.semibold))
                    Text("Image")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.55))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: liveActivityMaxHeight - (contentPadding * 2))
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .contentShape(.rect)
        .onTapGesture {
            isShowingImagePicker = true
        }
        .gesture(imageRepositionDragGesture)
        .photosPicker(isPresented: $isShowingImagePicker, selection: $backgroundImageSelection, matching: .images)
        .onChange(of: backgroundImageSelection) { _, newValue in
            loadBackgroundImage(newValue)
        }
    }

    private var imageRepositionDragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard contentImage != nil else { return }
                let baseOffset = imageDragStartOffsetY ?? viewModel.draft.style.imageOffsetY
                if imageDragStartOffsetY == nil { imageDragStartOffsetY = viewModel.draft.style.imageOffsetY }
                let maxOffset = max(0, (liveActivityMaxHeight - (contentPadding * 2)) / 2)
                viewModel.draft.style.imageOffsetY = min(maxOffset, max(-maxOffset, baseOffset + value.translation.height))
            }
            .onEnded { _ in imageDragStartOffsetY = nil }
    }

    private func loadBackgroundImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                viewModel.draft.style.backgroundImageData = ImagePreparation.preparedBackgroundImageData(from: data)
                viewModel.draft.style.imageOffsetY = 0
            }
        }
    }

    private var contentImage: Image? {
        #if canImport(UIKit)
        guard let data = viewModel.draft.style.backgroundImageData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private var editableMusicContent: some View {
        HStack(alignment: viewModel.draft.style.swiftUIVerticalAlignment, spacing: 16) {
            musicArtView

            if viewModel.draft.style.musicShowsTitle || viewModel.draft.style.musicShowsArtist || viewModel.draft.style.musicShowsAlbum {
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.draft.style.musicShowsTitle {
                        Text(viewModel.draft.musicTitle.isEmpty ? "Choose a song" : viewModel.draft.musicTitle)
                            .font(.system(size: viewModel.draft.style.textSize * 0.55, weight: .semibold, design: viewModel.draft.style.fontDesign))
                            .lineLimit(1)
                    }

                    if viewModel.draft.style.musicShowsArtist, !viewModel.draft.musicArtist.isEmpty {
                        Text(viewModel.draft.musicArtist)
                            .font(.system(size: viewModel.draft.style.textSize * 0.4, design: viewModel.draft.style.fontDesign))
                            .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.7))
                            .lineLimit(1)
                    }

                    if viewModel.draft.style.musicShowsAlbum, !viewModel.draft.musicAlbum.isEmpty {
                        Text(viewModel.draft.musicAlbum)
                            .font(.system(size: viewModel.draft.style.textSize * 0.34, design: viewModel.draft.style.fontDesign))
                            .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .contentShape(.rect)
                .onTapGesture {
                    onPickSong?()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: viewModel.draft.style.contentAlignment)
    }

    @ViewBuilder
    private var musicArtView: some View {
        let size = liveActivityMaxHeight - (contentPadding * 2)
        let shape = viewModel.draft.style.musicLayout.clipShape

        // Clip to the shape FIRST, then rotate that already-clipped "coin" as a rigid unit — the
        // opposite order (rotate the raw image, clip after) rotates the image's bounding box too,
        // so the fixed-size clip crops it inconsistently frame to frame as it spins. The border, if
        // enabled, is drawn as part of that same clipped unit so it spins along with the art instead
        // of staying fixed while the art rotates underneath it.
        let clippedArt = musicArtImage
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay {
                if viewModel.draft.style.musicBorderEnabled {
                    shape.stroke(Color(hex: viewModel.draft.style.musicBorderHex), lineWidth: 3)
                }
            }

        Group {
            if viewModel.draft.style.musicSpins {
                // Time-based rather than a discrete withAnimation(repeatForever) state jump — the
                // latter can visibly freeze whenever the view re-renders for an unrelated reason
                // (e.g. picking a new song swaps the art image), since that re-render can interrupt
                // the running transaction. Deriving the angle from wall-clock time every frame can't
                // "stop": it has no state to lose. Same pattern already used for the paywall marquee.
                TimelineView(.animation) { context in
                    clippedArt.rotationEffect(.degrees(spinAngle(at: context.date)))
                }
            } else {
                clippedArt
            }
        }
        // White outline only while the song-picker sheet is actually open, not just because this
        // content happens to be music — it marks "you're editing this right now", not "this is editable".
        .overlay {
            if isEditingMusic {
                shape.stroke(.white.opacity(0.85), lineWidth: 2)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            onPickSong?()
        }
    }

    @ViewBuilder
    private var musicArtImage: some View {
        if let image = musicAlbumArtImage {
            image
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.secondary.opacity(0.12)
                Image(systemName: "music.note")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.55))
            }
        }
    }

    private func spinAngle(at date: Date) -> Double {
        let duration = 8.0
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
        return progress * 360
    }

    private var musicAlbumArtImage: Image? {
        #if canImport(UIKit)
        guard let data = viewModel.draft.musicAlbumArtData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private var editableLiveActionsGrid: some View {
        LazyVGrid(columns: liveActionGridColumns, spacing: 10) {
            ForEach(viewModel.draft.liveActionItems.prefix(8)) { item in
                Button {
                    onEditLiveAction?(item.id)
                } label: {
                    liveActionTile(item)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: liveActionGridHeight, maxHeight: liveActionGridHeight, alignment: .center)
    }

    // Live action tiles are tiny and fixed-size, so the style's textSize (18–44, tuned for note/
    // checklist text) can't be used directly — it's scaled relative to its default and clamped,
    // then the tile clips so an extreme size can't spill outside its frame.
    private var liveActionFontScale: CGFloat {
        viewModel.draft.style.textSize / ActivityStyle.defaultTextSize
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
        .background(Color(hex: item.backgroundHex), in: .rect(cornerRadius: liveActionTileCornerRadius, style: .continuous))
        .clipped()
        .overlay {
            if selectedLiveActionID == item.id {
                RoundedRectangle(cornerRadius: liveActionTileCornerRadius, style: .continuous)
                    .strokeBorder(.white, lineWidth: 2.5)
                    .shadow(color: .white.opacity(0.35), radius: 6)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: selectedLiveActionID)
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

    // Column-major split (first half top-to-bottom in column 1, rest in column 2), matching
    // ActivityContentView/UnforgettyWidget exactly so the editor doesn't rearrange items relative
    // to the read-only preview and the real Live Activity.
    @ViewBuilder
    private var editableChecklistLayout: some View {
        let items = editableChecklistItems

        Group {
            if items.count > 3 {
                let firstColumnCount = (items.count + 1) / 2
                HStack(alignment: .top, spacing: 16) {
                    editableChecklistColumn(Array(items.prefix(firstColumnCount)))
                    editableChecklistColumn(Array(items.dropFirst(firstColumnCount)))
                }
            } else {
                editableChecklistColumn(items)
            }
        }
        .frame(maxWidth: .infinity, alignment: viewModel.draft.style.contentAlignment)
        .animation(.snappy, value: viewModel.draft.checklistItems.count)
    }

    private func editableChecklistColumn(_ items: [ChecklistItem]) -> some View {
        VStack(spacing: 16) {
            ForEach(items) { item in
                editableChecklistRow(item)
                    .transition(.blurReplace.combined(with: .scale))
            }
        }
    }

    private var editableChecklistItems: [ChecklistItem] {
        Array(viewModel.draft.checklistItems.prefix(maxInputLines))
    }

    // Bare style matching ActivityContentView.checklistRow exactly (checkbox + text, no
    // background pill) — only the TextField/checkbox tap targets and the trailing delete
    // button make it editable.
    private func editableChecklistRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleChecklistItem(item)
            } label: {
                checkbox(isCompleted: item.isCompleted, size: checkboxSize)
            }
            .buttonStyle(.plain)

            TextField("To Do", text: checklistItemTextBinding(for: item))
                .font(.system(size: viewModel.draft.style.textSize, design: viewModel.draft.style.fontDesign))
                .multilineTextAlignment(viewModel.draft.style.textAlignment)
                .strikethrough(item.isCompleted)
                .lineLimit(1)
                .focused($focusedField, equals: .checklist(item.id))
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }

            if viewModel.draft.checklistItems.count > 1 {
                Button {
                    removeChecklistItem(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: viewModel.draft.style.textHex).opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: viewModel.draft.style.contentAlignment)
        .contentShape(.rect)
    }

    private func loadTextStateFromDraft() {
        noteText = clampedText(viewModel.draft.body)
        checklistText = clampedText(viewModel.draft.checklistItems.map(\.text).joined(separator: "\n"))
    }

    private var noteTextBinding: Binding<String> {
        Binding {
            noteText
        } set: { newValue in
            let clamped = clampedText(newValue)
            noteText = clamped
            viewModel.draft.body = clamped
        }
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
        if let reminderID = viewModel.draft.checklistItems[index].reminderID {
            let isCompleted = viewModel.draft.checklistItems[index].isCompleted
            Task { await RemindersSyncService.setCompleted(isCompleted, reminderID: reminderID) }
        }
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

    private func checkbox(isCompleted: Bool, size: CGFloat) -> some View {
        let scheme = viewModel.draft.style.checklistScheme
        let color = Color(hex: viewModel.draft.style.textHex)

        return ZStack {
            if scheme == .circleCheckPadded {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size, height: size)
                Circle()
                    .fill(color)
                    .frame(width: size * 0.56, height: size * 0.56)
                    .opacity(isCompleted ? 1 : 0.22)
            } else if let emptySymbol = scheme.emptySymbol, let completedSymbol = scheme.completedSymbol {
                Image(systemName: isCompleted ? completedSymbol : emptySymbol)
                    .font(.system(size: size * scheme.symbolScale, weight: .semibold))
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size * scheme.symbolScale, height: size * scheme.symbolScale)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * scheme.symbolScale * 0.66, weight: .bold))
                }
            }
        }
        .contentShape(.rect)
    }

    private enum Field: Hashable {
        case note
        case checklist(UUID)
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

import ActivityKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

private func musicClipShape(for layout: String?) -> AnyShape {
    switch layout {
    case "square": AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    case "heart": AnyShape(HeartShape())
    case "diamond": AnyShape(DiamondShape())
    case "star": AnyShape(StarShape())
    default: AnyShape(Circle())
    }
}

nonisolated struct UnforgettyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var notificationID: String
        var fromUsername: String? = nil
        var message: String? = nil
        var friendSnapshot: FriendActivitySnapshot? = nil
    }
    var notificationID: String
}

struct UnforgettyWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UnforgettyActivityAttributes.self) { context in
            let draft = WidgetContentStore.draft(for: context.attributes.notificationID)
            let tintHex = draft?.style.backgroundHex ?? context.state.friendSnapshot?.backgroundHex ?? "172033"
            LockScreenActivityView(notificationID: context.attributes.notificationID, state: context.state)
                .activityBackgroundTint(Color(hex: tintHex).opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { _ in
            // v1 deliberately has no Dynamic Island presentation.
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { EmptyView() }
            } compactLeading: { EmptyView() } compactTrailing: { EmptyView() } minimal: { EmptyView() }
        }
    }
}

private struct UnforgettyHomeWidgetEntry: TimelineEntry {
    let date: Date
}

private struct UnforgettyHomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> UnforgettyHomeWidgetEntry {
        UnforgettyHomeWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (UnforgettyHomeWidgetEntry) -> Void) {
        completion(UnforgettyHomeWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnforgettyHomeWidgetEntry>) -> Void) {
        let entry = UnforgettyHomeWidgetEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct UnforgettyHomeWidget: Widget {
    private let kind = "com.gabrisp.Unforgetty.Widget.home"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UnforgettyHomeWidgetProvider()) { entry in
            UnforgettyHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Unforgetty")
        .description("Acceso rapido a tus actividades.")
        .supportedFamilies([.systemSmall])
    }
}

private struct UnforgettyHomeWidgetView: View {
    let entry: UnforgettyHomeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checklist.checked")
                .font(.title2.weight(.semibold))

            Text("Unforgetty")
                .font(.headline)

            Text("Crea una actividad para verla en directo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct FriendPingView: View {
    let fromUsername: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(fromUsername)")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// Shown instead of the real content while a friend-ping message hasn't been revealed yet — same
/// card design (background/gradient/border) as the real content, so "el design se mantiene", just
/// with the message hidden behind a tap. Revealing is one-way: once tapped, `RevealFriendMessageIntent`
/// marks it revealed in `WidgetContentStore` and this activity always shows the real content after.
private struct FriendMessageTeaserView: View {
    let notificationID: String
    let fromUsername: String
    let style: WidgetStyle
    let kind: String

    var body: some View {
        VStack(spacing: 10) {
            Text("Mensaje")
                .font(.headline.weight(.semibold))
            Text("de @\(fromUsername)")
                .font(.subheadline)
                .foregroundStyle(Color(hex: style.textHex).opacity(0.7))
            Button(intent: RevealFriendMessageIntent(notificationID: notificationID)) {
                Text("Ver")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(Color(hex: style.textHex))
        .frame(maxWidth: .infinity, maxHeight: 160)
        .widgetActivityBackground(style: style, kind: kind)
    }
}

/// Renders a friend ping's actual note content (not just the accompanying message) — the
/// snapshot rides in the push's content-state since the receiving device has no local draft.
private struct FriendSnapshotView: View {
    let notificationID: String
    let fromUsername: String
    let message: String?
    let snapshot: FriendActivitySnapshot

    private var style: WidgetStyle {
        WidgetStyle(
            backgroundHex: snapshot.backgroundHex,
            gradientStartHex: snapshot.gradientStartHex,
            gradientEndHex: snapshot.gradientEndHex,
            gradientKind: snapshot.gradientKind,
            gradientAngle: snapshot.gradientAngle,
            gradientCenterX: snapshot.gradientCenterX,
            gradientCenterY: snapshot.gradientCenterY,
            backgroundImageData: nil,
            textHex: snapshot.textHex,
            backgroundMode: snapshot.backgroundMode,
            font: snapshot.font,
            textSize: snapshot.textSize,
            alignment: snapshot.alignment,
            verticalAlignment: snapshot.verticalAlignment,
            lineSpacingMultiplier: snapshot.lineSpacingMultiplier,
            borderHex: snapshot.borderHex,
            borderWidth: snapshot.borderWidth,
            checklistScheme: nil
        )
    }

    private var noteText: String {
        let trimmed = snapshot.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Note" : snapshot.body
    }

    private var showsTeaser: Bool {
        guard let message, !message.isEmpty else { return false }
        return !WidgetContentStore.isFriendMessageRevealed(notificationID: notificationID)
    }

    var body: some View {
        Group {
            if showsTeaser {
                FriendMessageTeaserView(notificationID: notificationID, fromUsername: fromUsername, style: style, kind: "note")
            } else {
                realContent
            }
        }
        .contentShape(.rect)
        // No hide-content toggle exists for a friend ping, so unlike a local note the whole card
        // is free to be the tap target that opens the app to this ping's saved preview.
        .widgetURL(URL(string: "unforgetty://friend-ping/\(notificationID)"))
        .onAppear {
            WidgetContentStore.saveReceivedFriendPing(
                notificationID: notificationID,
                fromUsername: fromUsername,
                message: message,
                snapshot: snapshot
            )
        }
    }

    private var realContent: some View {
        VStack(alignment: style.horizontalAlignment, spacing: 8) {
            Text(noteText)
                .font(.system(size: style.textSize, weight: .medium, design: style.fontDesign))
                .multilineTextAlignment(style.textAlignment)
                .lineSpacing(style.textSize * (style.lineSpacingMultiplier ?? 0.15))
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: style.contentAlignment)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color(hex: style.textHex).opacity(0.62))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: style.contentAlignment)
            }
        }
        .foregroundStyle(Color(hex: style.textHex))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 160, alignment: style.contentAlignment)
        .widgetActivityBackground(style: style, kind: "note")
        .overlay(alignment: .topTrailing) {
            Text("Sent by @\(fromUsername)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hex: style.textHex).opacity(0.62))
                .padding(.top, 10)
                .padding(.leading, 10)
                .padding(.trailing, 14)
        }
    }
}

/// Renders a friend ping's music track — title/artist + the inline message directly in the card
/// (not a small corner badge, unlike the note variant, since the user asked for the message to
/// read inline). Tapping the main card plays the track in Spotify; the small "sent by" label is
/// its own separate tap target that opens the app's received-ping sheet instead.
private struct FriendMusicSnapshotView: View {
    let notificationID: String
    let fromUsername: String
    let message: String?
    let snapshot: FriendActivitySnapshot
    @State private var albumArtData: Data?

    private var style: WidgetStyle {
        WidgetStyle(
            backgroundHex: snapshot.backgroundHex,
            gradientStartHex: snapshot.gradientStartHex,
            gradientEndHex: snapshot.gradientEndHex,
            gradientKind: snapshot.gradientKind,
            gradientAngle: snapshot.gradientAngle,
            gradientCenterX: snapshot.gradientCenterX,
            gradientCenterY: snapshot.gradientCenterY,
            backgroundImageData: nil,
            textHex: snapshot.textHex,
            backgroundMode: snapshot.backgroundMode,
            font: snapshot.font,
            textSize: snapshot.textSize,
            alignment: snapshot.alignment,
            verticalAlignment: snapshot.verticalAlignment,
            lineSpacingMultiplier: snapshot.lineSpacingMultiplier,
            borderHex: snapshot.borderHex,
            borderWidth: snapshot.borderWidth,
            checklistScheme: nil
        )
    }

    private var albumArtImage: Image? {
        #if canImport(UIKit)
        guard let albumArtData, let uiImage = ImageDecodeCache.image(for: albumArtData) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private var playURL: URL? {
        snapshot.musicSpotifyURL.flatMap { URL(string: $0) }
    }

    private var showsTeaser: Bool {
        guard let message, !message.isEmpty else { return false }
        return !WidgetContentStore.isFriendMessageRevealed(notificationID: notificationID)
    }

    var body: some View {
        Group {
            if showsTeaser {
                FriendMessageTeaserView(notificationID: notificationID, fromUsername: fromUsername, style: style, kind: "music")
            } else {
                realContent
            }
        }
        .contentShape(.rect)
        .onAppear {
            WidgetContentStore.saveReceivedFriendPing(
                notificationID: notificationID,
                fromUsername: fromUsername,
                message: message,
                snapshot: snapshot
            )
            fetchAlbumArtIfNeeded()
        }
    }

    private var realContent: some View {
        HStack(alignment: style.swiftUIVerticalAlignment, spacing: 16) {
            if snapshot.musicArtPosition == "leading" {
                musicArtGroup
                musicTextGroup
            } else {
                musicTextGroup
                musicArtGroup
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(hex: style.textHex))
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: 160, alignment: style.contentAlignment)
        .widgetActivityBackground(style: style, kind: "music")
        .overlay(alignment: .topTrailing) {
            if let sheetURL = URL(string: "unforgetty://friend-ping/\(notificationID)") {
                Link(destination: sheetURL) {
                    Text("Sent by @\(fromUsername)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: style.textHex).opacity(0.62))
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        .padding(.trailing, 14)
                }
            }
        }
    }

    private var musicArtGroup: some View {
        let art = Group {
            if let albumArtImage {
                albumArtImage
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(hex: style.textHex).opacity(0.55))
                }
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(musicClipShape(for: snapshot.musicLayout))
        .overlay {
            if snapshot.musicBorderEnabled {
                musicClipShape(for: snapshot.musicLayout).stroke(Color(hex: snapshot.musicBorderHex), lineWidth: 3)
            }
        }

        // Same reasoning as the own-draft music card: only the circle opens Spotify, via an
        // AppIntent-backed tap target — the surrounding card keeps its plain `.widgetURL` to
        // `unforgetty://friend-ping/...` (see the "Sent by" Link above) for everything else.
        return Group {
            if let playURL {
                Button(intent: OpenExternalLinkIntent(urlString: playURL.absoluteString)) {
                    art
                }
                .buttonStyle(.plain)
            } else {
                art
            }
        }
    }

    @ViewBuilder
    private var musicTextGroup: some View {
        VStack(alignment: .leading, spacing: 4) {
            if snapshot.musicShowsTitle {
                Text((snapshot.musicTitle?.isEmpty ?? true) ? "Music" : snapshot.musicTitle!)
                    .font(.system(size: style.textSize * 0.5, weight: .semibold, design: style.fontDesign))
                    .lineLimit(1)
            }
            if snapshot.musicShowsArtist, let artist = snapshot.musicArtist, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: style.textSize * 0.38, design: style.fontDesign))
                    .foregroundStyle(Color(hex: style.textHex).opacity(0.7))
                    .lineLimit(1)
            }
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: style.textSize * 0.34, design: style.fontDesign))
                    .foregroundStyle(Color(hex: style.textHex).opacity(0.85))
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
    }

    private func fetchAlbumArtIfNeeded() {
        guard albumArtData == nil else { return }
        if let cached = WidgetContentStore.musicAlbumArt(notificationID: notificationID) {
            albumArtData = cached
            return
        }
        guard let urlString = snapshot.musicAlbumArtURL, let url = URL(string: urlString) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            WidgetContentStore.saveMusicAlbumArt(notificationID: notificationID, data: data)
            await MainActor.run {
                albumArtData = data
            }
            // A Live Activity view's @State update alone isn't a reliable repaint signal here —
            // this download can finish after the widget process's initial render already
            // completed (confirmed pattern: see LiveActivityController.start's equivalent race for
            // locally-started activities). Force an explicit re-render once the art is on disk.
            await WidgetLiveActivityRefresher.refresh(notificationID: notificationID)
        }
    }
}

/// A friend's `.image`-kind card — the photo itself is the whole content, uploaded to the
/// "images" Storage bucket right before sending (see CreateActivityV2EditViewModel.send()) since
/// raw bytes don't fit the push payload. Fetch/cache mechanics mirror
/// FriendMusicSnapshotView's album art exactly, reusing the same cache (keyed by notificationID,
/// generic despite the "musicAlbumArt" name — a given ping is only ever one kind, so there's no
/// collision risk sharing it instead of adding a parallel image-only cache).
private struct FriendImageSnapshotView: View {
    let notificationID: String
    let fromUsername: String
    let message: String?
    let snapshot: FriendActivitySnapshot
    @State private var imageData: Data?

    private var style: WidgetStyle {
        WidgetStyle(
            backgroundHex: snapshot.backgroundHex,
            gradientStartHex: snapshot.gradientStartHex,
            gradientEndHex: snapshot.gradientEndHex,
            gradientKind: snapshot.gradientKind,
            gradientAngle: snapshot.gradientAngle,
            gradientCenterX: snapshot.gradientCenterX,
            gradientCenterY: snapshot.gradientCenterY,
            backgroundImageData: nil,
            textHex: snapshot.textHex,
            backgroundMode: snapshot.backgroundMode,
            font: snapshot.font,
            textSize: snapshot.textSize,
            alignment: snapshot.alignment,
            verticalAlignment: snapshot.verticalAlignment,
            lineSpacingMultiplier: snapshot.lineSpacingMultiplier,
            borderHex: snapshot.borderHex,
            borderWidth: snapshot.borderWidth,
            checklistScheme: nil
        )
    }

    private var contentImage: Image? {
        #if canImport(UIKit)
        guard let imageData, let uiImage = ImageDecodeCache.image(for: imageData) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private var showsTeaser: Bool {
        guard let message, !message.isEmpty else { return false }
        return !WidgetContentStore.isFriendMessageRevealed(notificationID: notificationID)
    }

    var body: some View {
        Group {
            if showsTeaser {
                FriendMessageTeaserView(notificationID: notificationID, fromUsername: fromUsername, style: style, kind: "image")
            } else {
                realContent
            }
        }
        .contentShape(.rect)
        // No Spotify-style external link here (unlike music's circle) — the whole card just
        // opens the app to this ping's saved preview, same as the note variant.
        .widgetURL(URL(string: "unforgetty://friend-ping/\(notificationID)"))
        .onAppear {
            WidgetContentStore.saveReceivedFriendPing(
                notificationID: notificationID,
                fromUsername: fromUsername,
                message: message,
                snapshot: snapshot
            )
            fetchImageIfNeeded()
        }
    }

    private var realContent: some View {
        Group {
            if let contentImage {
                contentImage
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "photo")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(hex: style.textHex).opacity(0.55))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 160)
        .clipped()
        .overlay(alignment: .topTrailing) {
            Text("Sent by @\(fromUsername)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 10)
                .padding(.trailing, 14)
        }
        .overlay(alignment: .bottomLeading) {
            if let message, !message.isEmpty {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
            }
        }
    }

    private func fetchImageIfNeeded() {
        guard imageData == nil else { return }
        if let cached = WidgetContentStore.musicAlbumArt(notificationID: notificationID) {
            imageData = cached
            return
        }
        guard let urlString = snapshot.imageURL, let url = URL(string: urlString) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            WidgetContentStore.saveMusicAlbumArt(notificationID: notificationID, data: data)
            await MainActor.run {
                imageData = data
            }
            await WidgetLiveActivityRefresher.refresh(notificationID: notificationID)
        }
    }
}

/// `.widgetURL` requires a non-optional `URL`, but the track's Spotify link is only known once a
/// snapshot decodes successfully — this keeps the call site a plain optional instead of forcing a
/// throwaway fallback URL.
private struct OptionalWidgetURL: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            content.widgetURL(url)
        } else {
            content
        }
    }
}

private struct LockScreenActivityView: View {
    let notificationID: String
    let state: UnforgettyActivityAttributes.ContentState
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    private var draft: WidgetDraft? {
        WidgetContentStore.draft(for: notificationID)
    }
    var body: some View {
        if let draft {
            interactiveActivityContent(for: draft)
        } else if let fromUsername = state.fromUsername, let snapshot = state.friendSnapshot, snapshot.kind == "music" {
            FriendMusicSnapshotView(notificationID: notificationID, fromUsername: fromUsername, message: state.message, snapshot: snapshot)
        } else if let fromUsername = state.fromUsername, let snapshot = state.friendSnapshot, snapshot.kind == "image" {
            FriendImageSnapshotView(notificationID: notificationID, fromUsername: fromUsername, message: state.message, snapshot: snapshot)
        } else if let fromUsername = state.fromUsername, let snapshot = state.friendSnapshot {
            FriendSnapshotView(notificationID: notificationID, fromUsername: fromUsername, message: state.message, snapshot: snapshot)
        } else if let fromUsername = state.fromUsername, let message = state.message {
            FriendPingView(fromUsername: fromUsername, message: message)
        } else {
            Text("Abre Unforgetty para recuperar esta actividad.").padding()
        }
    }

    @ViewBuilder
    private func interactiveActivityContent(for draft: WidgetDraft) -> some View {
        if draft.kind == "note", draft.blurContentMode == "tapToToggle" {
            Toggle(isOn: draft.isContentBlurred ?? true, intent: ToggleBlurIntent(notificationID: notificationID)) {
                activityContent(for: draft, appliesContentBlur: false)
            }
            .toggleStyle(LiveActivityBlurToggleStyle())
        } else {
            activityContent(for: draft)
        }
    }

    private func activityContent(for draft: WidgetDraft, appliesContentBlur: Bool = true) -> some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 14) {
            if draft.kind == "note" {
                Text(noteText(for: draft))
                    .font(.system(size: draft.style.textSize, weight: .medium, design: draft.style.fontDesign))
                    .multilineTextAlignment(draft.style.textAlignment)
                    .lineSpacing(draft.style.textSize * (draft.style.lineSpacingMultiplier ?? 0.15))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                    .opacity(isNotePlaceholder(draft) ? 0.45 : 1)
            }
            else if draft.kind == "image" {
                imageContent(for: draft)
            }
            else if draft.kind == "music" {
                musicContent(for: draft)
            }
            else if draft.kind == "check.buttons" || draft.kind == "buttons" {
                liveActionsGrid(for: draft)
            } else {
                if displayedChecklistItems(for: draft).count > 3 {
                    let firstColumnCount = (displayedChecklistItems(for: draft).count + 1) / 2
                    HStack(alignment: .top, spacing: 16) {
                        checklistColumn(Array(displayedChecklistItems(for: draft).prefix(firstColumnCount)), draft: draft)
                        checklistColumn(Array(displayedChecklistItems(for: draft).dropFirst(firstColumnCount)), draft: draft)
                    }
                    .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                } else {
                    checklistColumn(displayedChecklistItems(for: draft), draft: draft)
                        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
                }
            }
        }
        .foregroundStyle(Color(hex: draft.style.textHex))
        .blur(radius: appliesContentBlur && isContentBlurred(for: draft) ? 10 : 0)
        .padding(contentPadding(for: draft))
        .frame(maxWidth: .infinity, maxHeight: 160, alignment: draft.style.contentAlignment)
        .widgetActivityBackground(style: draft.style, kind: draft.kind)
        .contentShape(.rect)
        .modifier(OptionalWidgetURL(url: draft.kind == "music" ? draft.musicSpotifyURL.flatMap(URL.init) : nil))
    }

    private func liveActionsGrid(for draft: WidgetDraft) -> some View {
        let count = min(draft.liveActionItems?.count ?? 0, 8)
        let capacity = liveActionGridCapacity(for: count)
        // Live action tiles are tiny and fixed-size, so the style's textSize (18–44, tuned for
        // note/checklist text) can't be used directly — scale relative to its default instead.
        let fontScale = draft.style.textSize / 40

        return LazyVGrid(columns: liveActionGridColumns(for: capacity), spacing: 10) {
            ForEach(Array((draft.liveActionItems ?? []).prefix(8))) { item in
                Button(intent: RunLiveActionIntent(item: item)) {
                    liveActionTile(item, capacity: capacity, fontScale: fontScale)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 136, maxHeight: 136, alignment: .center)
    }

    private func liveActionGridCapacity(for count: Int) -> Int {
        if count <= 1 { return 1 }
        if count <= 2 { return 2 }
        if count <= 4 { return 4 }
        if count <= 6 { return 6 }
        return 8
    }

    private func liveActionGridColumns(for capacity: Int) -> [GridItem] {
        let columnCount = capacity <= 2 ? capacity : capacity / 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, columnCount))
    }

    private func imageContent(for draft: WidgetDraft) -> some View {
        Group {
            if let image = widgetContentImage(from: draft.style.backgroundImageData) {
                image
                    .resizable()
                    .scaledToFill()
                    .offset(y: draft.style.imageOffsetY ?? 0)
            } else {
                Image(systemName: "photo")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160 - (contentPadding(for: draft) * 2))
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }

    private func widgetContentImage(from data: Data?) -> Image? {
        #if canImport(UIKit)
        guard let data, let uiImage = ImageDecodeCache.image(for: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    // Static — no continuous animation runs inside a Live Activity's ActivityConfiguration
    // content (WidgetKit only re-renders on real content-state changes, not a persistent loop).
    private func musicContent(for draft: WidgetDraft) -> some View {
        HStack(alignment: draft.style.swiftUIVerticalAlignment, spacing: 16) {
            if draft.style.musicArtPosition == "leading" {
                musicArtGroup(for: draft)
                musicTextGroup(for: draft)
            } else {
                musicTextGroup(for: draft)
                musicArtGroup(for: draft)
            }
        }
        .frame(maxWidth: .infinity, alignment: draft.style.contentAlignment)
    }

    @ViewBuilder
    private func musicTextGroup(for draft: WidgetDraft) -> some View {
        if draft.style.musicShowsTitle != false || draft.style.musicShowsArtist != false || draft.style.musicShowsAlbum != false {
            VStack(alignment: .leading, spacing: 4) {
                if draft.style.musicShowsTitle != false {
                    Text((draft.musicTitle?.isEmpty ?? true) ? "Music" : draft.musicTitle!)
                        .font(.system(size: draft.style.textSize * 0.55, weight: .semibold, design: draft.style.fontDesign))
                        .lineLimit(1)
                }
                if draft.style.musicShowsArtist != false, let artist = draft.musicArtist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: draft.style.textSize * 0.4, design: draft.style.fontDesign))
                        .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.7))
                        .lineLimit(1)
                }
                if draft.style.musicShowsAlbum != false, let album = draft.musicAlbum, !album.isEmpty {
                    Text(album)
                        .font(.system(size: draft.style.textSize * 0.34, design: draft.style.fontDesign))
                        .foregroundStyle(Color(hex: draft.style.textHex).opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
    }

    private func musicArtGroup(for draft: WidgetDraft) -> some View {
        let art = Group {
            if let image = widgetContentImage(from: draft.musicAlbumArtData) {
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
        .clipShape(musicClipShape(for: draft.style.musicLayout))
        .overlay {
            if draft.style.musicBorderEnabled == true {
                musicClipShape(for: draft.style.musicLayout).stroke(Color(hex: draft.style.musicBorderHex ?? "FFFFFF"), lineWidth: 3)
            }
        }

        // The circle is the one part of a music card that opens Spotify — a plain `.widgetURL` on
        // the card can only route back into this app, so this needs its own AppIntent-backed tap
        // target (see OpenExternalLinkIntent's doc comment for why it launches the app instead of
        // chaining straight to a URL).
        return Group {
            if let spotifyURL = draft.musicSpotifyURL, !spotifyURL.isEmpty {
                Button(intent: OpenExternalLinkIntent(urlString: spotifyURL)) {
                    art
                }
                .buttonStyle(.plain)
            } else {
                art
            }
        }
    }

    private func liveActionTile(_ item: WidgetLiveActionItem, capacity: Int, fontScale: Double) -> some View {
        let showsTitle = capacity < 6

        return HStack(spacing: showsTitle ? 7 : 0) {
            liveActionIcon(item, showsTitle: showsTitle, fontScale: fontScale)

            if showsTitle {
                Text(item.title)
                    .font(.system(size: min(max(10 * fontScale, 7), 15), weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Color(hex: item.textHex))
        // .padding(.horizontal, showsTitle ? 8 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: capacity <= 2 ? 136 : 64)
        .background(Color(hex: item.backgroundHex), in: .rect(cornerRadius: 16, style: .continuous))
        .clipped()
    }

    @ViewBuilder
    private func liveActionIcon(_ item: WidgetLiveActionItem, showsTitle: Bool, fontScale: Double) -> some View {
        if let emoji = item.customIcon?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty {
            Text(String(emoji.prefix(2)))
                .font(.system(size: min(max((showsTitle ? 22 : 26) * fontScale, 14), 34)))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: item.icon)
                .font(.system(size: min(max((showsTitle ? 20 : 24) * fontScale, 12), 32), weight: .semibold))
                .frame(width: 30, height: 30)
        }
    }

    private func contentPadding(for draft: WidgetDraft) -> CGFloat {
        if draft.kind == "check.buttons" || draft.kind == "buttons" { return 12 }
        if draft.kind == "image" { return draft.style.imageInset ?? 24 }
        if draft.kind == "music" { return 24 }
        return 24
    }

    private func checkbox(isCompleted: Bool, color: Color, textSize: Double, scheme: String?) -> some View {
        let rowHeight = max(32, CGFloat(textSize) * 1.22)
        let size = min(rowHeight, max(24, CGFloat(textSize) * 1.08))
        let circleScale: CGFloat = scheme == "circleCheckPadded" ? 0.76 : 1

        return ZStack {
            if scheme == "circleCheckPadded" {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size, height: size)
                Circle()
                    .fill(color)
                    .frame(width: size * 0.56, height: size * 0.56)
                    .opacity(isCompleted ? 1 : 0.22)
            } else if let symbols = checklistSymbols(for: scheme) {
                Image(systemName: isCompleted ? symbols.completed : symbols.empty)
                    .font(.system(size: size * symbols.scale, weight: .semibold))
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size * circleScale, height: size * circleScale)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * circleScale * 0.66, weight: .bold))
                }
            }
        }
    }

    private func checklistSymbols(for scheme: String?) -> (empty: String, completed: String, scale: CGFloat)? {
        switch scheme {
        case "square":
            ("square", "square.fill", 0.82)
        case "squarePadded":
            ("square", "square.fill", 0.66)
        case "flame":
            ("flame", "flame.fill", 1)
        case "tennisball":
            ("tennisball", "tennisball.fill", 1)
        case "heart":
            ("heart", "heart.fill", 1)
        case "star":
            ("star", "star.fill", 1)
        case "diamond":
            ("diamond", "diamond.fill", 1)
        default:
            nil
        }
    }

    private func noteText(for draft: WidgetDraft) -> String {
        isNotePlaceholder(draft) ? "Note" : draft.body
    }

    private func isNotePlaceholder(_ draft: WidgetDraft) -> Bool {
        draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isContentBlurred(for draft: WidgetDraft) -> Bool {
        switch draft.blurContentMode {
        case "tapToToggle":
            return draft.kind == "note" && (draft.isContentBlurred ?? true)
        case "whenLuminanceReduced":
            return isLuminanceReduced
        default:
            return false
        }
    }

    private func checklistText(for item: WidgetChecklistItem) -> String {
        isChecklistPlaceholder(item) ? "To Do" : item.text
    }

    private func isChecklistPlaceholder(_ item: WidgetChecklistItem) -> Bool {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func displayedChecklistItems(for draft: WidgetDraft) -> [WidgetChecklistItem] {
        let items = draft.hideCompletedChecklistItems == true
            ? draft.checklistItems.filter { !$0.isCompleted }
            : draft.checklistItems
        return Array(items.prefix(6))
    }

    private func checklistColumn(_ items: [WidgetChecklistItem], draft: WidgetDraft) -> some View {
        VStack(alignment: draft.style.horizontalAlignment, spacing: 16) {
            ForEach(items) { item in
                checklistRow(item, draft: draft)
            }
        }
    }

    private func checklistRow(_ item: WidgetChecklistItem, draft: WidgetDraft) -> some View {
        Toggle(isOn: item.isCompleted, intent: ToggleChecklistItemIntent(notificationID: notificationID, itemID: item.id)) {
            Text(checklistText(for: item))
                .font(.system(size: draft.style.textSize, design: draft.style.fontDesign))
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isChecklistPlaceholder(item) ? 0.45 : 1)
        }
        .toggleStyle(WidgetChecklistToggleStyle(
            textHex: draft.style.textHex,
            textSize: draft.style.textSize,
            checklistScheme: draft.style.checklistScheme,
            contentAlignment: draft.style.contentAlignment
        ))
    }
}

private struct LiveActivityBlurToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .blur(radius: configuration.isOn ? 10 : 0)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct WidgetChecklistToggleStyle: ToggleStyle {
    let textHex: String
    let textSize: Double
    let checklistScheme: String?
    let contentAlignment: Alignment

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                checkbox(isCompleted: configuration.isOn)
                configuration.label
                    .strikethrough(configuration.isOn)
            }
            .frame(maxWidth: .infinity, alignment: contentAlignment)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var checkboxSize: CGFloat {
        let rowHeight = max(32, CGFloat(textSize) * 1.22)
        return min(rowHeight, max(24, CGFloat(textSize) * 1.08))
    }

    private func checkbox(isCompleted: Bool) -> some View {
        let circleScale: CGFloat = checklistScheme == "circleCheckPadded" ? 0.76 : 1

        return ZStack {
            if checklistScheme == "circleCheckPadded" {
                Circle()
                    .stroke(Color(hex: textHex), lineWidth: 2)
                    .frame(width: checkboxSize, height: checkboxSize)
                Circle()
                    .fill(Color(hex: textHex))
                    .frame(width: checkboxSize * 0.56, height: checkboxSize * 0.56)
                    .opacity(isCompleted ? 1 : 0.22)
            } else if let symbols = checklistSymbols {
                Image(systemName: isCompleted ? symbols.completed : symbols.empty)
                    .font(.system(size: checkboxSize * symbols.scale, weight: .semibold))
                    .frame(width: checkboxSize, height: checkboxSize)
            } else {
                Circle()
                    .stroke(Color(hex: textHex), lineWidth: 2)
                    .frame(width: checkboxSize * circleScale, height: checkboxSize * circleScale)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: checkboxSize * circleScale * 0.66, weight: .bold))
                }
            }
        }
    }

    private var checklistSymbols: (empty: String, completed: String, scale: CGFloat)? {
        switch checklistScheme {
        case "square":
            ("square", "square.fill", 0.82)
        case "squarePadded":
            ("square", "square.fill", 0.66)
        case "flame":
            ("flame", "flame.fill", 1)
        case "tennisball":
            ("tennisball", "tennisball.fill", 1)
        case "heart":
            ("heart", "heart.fill", 1)
        case "star":
            ("star", "star.fill", 1)
        case "diamond":
            ("diamond", "diamond.fill", 1)
        default:
            nil
        }
    }
}

private extension WidgetStyle {
    var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }

    var textAlignment: TextAlignment {
        switch alignment {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }

    var swiftUIVerticalAlignment: VerticalAlignment {
        switch verticalAlignment {
        case "top": .top
        case "bottom": .bottom
        default: .center
        }
    }

    var contentAlignment: Alignment {
        Alignment(horizontal: horizontalAlignment, vertical: swiftUIVerticalAlignment)
    }

    var fontDesign: Font.Design {
        switch font {
        case "serif": .serif
        case "monospaced": .monospaced
        default: .rounded
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetActivityBackground(style: WidgetStyle, kind: String) -> some View {
        switch style.backgroundMode {
        case "gradient":
            background {
                widgetGradient(style: style)
            }
            .innerWidgetBorder(style: style)
        case "image":
            if kind == "note", let image = widgetBackgroundImage(from: style.backgroundImageData) {
                background {
                    image
                        .resizable()
                        .scaledToFill()
                }
                .innerWidgetBorder(style: style)
            } else {
                background(Color(hex: style.backgroundHex))
                    .innerWidgetBorder(style: style)
            }
        default:
            background(Color(hex: style.backgroundHex).opacity(0.6))
                .innerWidgetBorder(style: style)
        }
    }

    @ViewBuilder
    private func widgetGradient(style: WidgetStyle) -> some View {
        let colors = [
            Color(hex: style.gradientStartHex ?? style.backgroundHex).opacity(0.6),
            Color(hex: style.gradientEndHex ?? "D7E6FF").opacity(0.6)
        ]
        let center = UnitPoint(
            x: min(1, max(0, style.gradientCenterX ?? 0.5)),
            y: min(1, max(0, style.gradientCenterY ?? 0.5))
        )
        let angle = style.gradientAngle ?? 135

        switch style.gradientKind {
        case "radial":
            RadialGradient(colors: colors, center: center, startRadius: 0, endRadius: 260)
        case "angular":
            AngularGradient(colors: colors, center: center, angle: .degrees(angle))
        default:
            LinearGradient(
                colors: colors,
                startPoint: widgetGradientEndpoint(angle: angle + 180),
                endPoint: widgetGradientEndpoint(angle: angle)
            )
        }
    }

    private func widgetGradientEndpoint(angle: Double) -> UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(
            x: 0.5 + (cos(radians) * 0.5),
            y: 0.5 + (sin(radians) * 0.5)
        )
    }

    @ViewBuilder
    private func innerWidgetBorder(style: WidgetStyle) -> some View {
        if let width = style.borderWidth, width > 0 {
            overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(hex: style.borderHex ?? "FFFFFF"), lineWidth: CGFloat(width))
            }
        } else {
            self
        }
    }

    private func widgetBackgroundImage(from data: Data?) -> Image? {
        #if canImport(UIKit)
        guard let data, let uiImage = ImageDecodeCache.image(for: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}

private extension Color {
    init(hex: String) { let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0; self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255) }
}

@main struct UnforgettyWidgetBundle: WidgetBundle {
    var body: some Widget {
        UnforgettyHomeWidget()
        UnforgettyWidget()
    }
}

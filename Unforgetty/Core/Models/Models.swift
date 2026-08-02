import Foundation
import SwiftUI

enum ActivityKind: Codable, CaseIterable, Identifiable, Hashable {
    case note
    case image
    case music
    case check(CheckKind)

    enum CheckKind: String, Codable, CaseIterable, Identifiable {
        case buttons
        case todoList

        var id: Self { self }
        var title: String {
            switch self {
            case .buttons: "LiveActions"
            case .todoList: "To Do"
            }
        }
    }

    static var checklist: Self { .check(.todoList) }
    static var allCases: [Self] { [.note, .image, .music, .check(.buttons), .check(.todoList)] }

    var id: String {
        switch self {
        case .note: "note"
        case .image: "image"
        case .music: "music"
        case .check(let checkKind): "check.\(checkKind.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .note: "Text"
        case .image: "Image"
        case .music: "Music"
        case .check(let checkKind): checkKind.title
        }
    }

    var isNote: Bool { self == .note }
    var isCheck: Bool {
        if case .check = self { return true }
        return false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "note":
            self = .note
        case "image":
            self = .image
        case "music":
            self = .music
        case "check.buttons", "buttons":
            self = .check(.buttons)
        case "check.todoList", "todoList", "checklist":
            self = .check(.todoList)
        default:
            self = .check(.todoList)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .note:
            try container.encode("note")
        case .image:
            try container.encode("image")
        case .music:
            try container.encode("music")
        case .check(.buttons):
            try container.encode("check.buttons")
        case .check(.todoList):
            try container.encode("checklist")
        }
    }
}

enum ActivityStatus: String, Codable, CaseIterable, Identifiable {
    case draft, active, scheduled, completed
    var id: Self { self }
    var title: String {
        switch self {
        case .draft: "Borrador"
        case .active: "Activas"
        case .scheduled: "Programadas"
        case .completed: "Completadas"
        }
    }
}

enum ActivitySurface: String, Codable, CaseIterable, Identifiable {
    case liveActivity, notification, widget
    var id: Self { self }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: Self { self }
    var shortLabel: String {
        switch self {
        case .monday: "L"
        case .tuesday: "M"
        case .wednesday: "X"
        case .thursday: "J"
        case .friday: "V"
        case .saturday: "S"
        case .sunday: "D"
        }
    }

    /// `Calendar.component(.weekday, from:)` returns 1 = Sunday ... 7 = Saturday.
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}

struct Tag: Codable, Identifiable, Hashable { var id = UUID(); var name: String }
struct ChecklistItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var isCompleted = false
    var reminderID: String?

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, reminderID: String? = nil) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.reminderID = reminderID
    }
}

enum LiveActionKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case shortcut
    case openApp
    case openLink

    var id: Self { self }

    var title: String {
        switch self {
        case .shortcut: "Shortcut"
        case .openApp: "Open App"
        case .openLink: "Open Link"
        }
    }
}

struct LiveActionItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var kind: LiveActionKind
    var icon: String
    var customIcon: String?
    var backgroundHex: String
    var textHex: String
    var target: String
    var shortcutInput: String?

    init(
        id: UUID = UUID(),
        title: String,
        kind: LiveActionKind,
        icon: String,
        customIcon: String? = nil,
        backgroundHex: String = "6251F6",
        textHex: String = "FFFFFF",
        target: String = "",
        shortcutInput: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.icon = icon
        self.customIcon = customIcon
        self.backgroundHex = backgroundHex
        self.textHex = textHex
        self.target = target
        self.shortcutInput = shortcutInput
    }
}

enum BlurContentMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case tapToToggle
    case never
    case whenLuminanceReduced

    var id: Self { self }

    var title: String {
        switch self {
        case .tapToToggle: "Toggle"
        case .never: "Nunca"
        case .whenLuminanceReduced: "Con pantalla atenuada"
        }
    }
}

struct ActivityStyle: Codable, Hashable {
    static let minimumTextSize: Double = 18
    static let maximumTextSize: Double = 44
    static let defaultTextSize: Double = 40

    var backgroundHex = "F6F6F7"
    var gradientStartHex = "F6F6F7"
    var gradientEndHex = "D7E6FF"
    var gradientKind = GradientKind.linear
    var gradientAngle: Double = 135
    var gradientCenterX: Double = 0.5
    var gradientCenterY: Double = 0.5
    var backgroundImageData: Data?
    /// Uploaded to the "images" Storage bucket right before a `.image`-kind activity is sent to a
    /// friend — raw bytes can't fit in the ~4KB push payload (same constraint music album art has,
    /// solved the same way via `musicAlbumArtURL`), so this URL is what actually crosses devices.
    var backgroundImageURL: String?
    /// Set once the user manually touches any background control — before that, `.music` content
    /// is free to auto-derive a gradient from the picked track's album art without clobbering a
    /// deliberate choice.
    var backgroundIsCustomized = false
    var textHex = "111111"
    var backgroundMode = BackgroundMode.plain
    var font = FontChoice.rounded
    var textSize: Double = Self.defaultTextSize
    var alignment = TextAlignmentChoice.leading
    var verticalAlignment = VerticalAlignmentChoice.center
    /// Multiplier of `textSize` used as `.lineSpacing(...)` for multi-line note text — kept
    /// relative to text size (not an absolute point value) so it scales sensibly across the whole
    /// size range instead of looking cramped at 18pt or excessive at 44pt.
    static let defaultLineSpacingMultiplier: Double = 0.15
    var lineSpacingMultiplier: Double = Self.defaultLineSpacingMultiplier
    var borderHex = "FFFFFF"
    var borderWidth: Double = 0
    var checklistScheme = ChecklistScheme.circleCheck
    /// Only used for `.image` content — its own inset instead of sharing the note/checklist one,
    /// since the user should be able to make the photo fill the card edge-to-edge.
    static let defaultImageInset: Double = 24
    var imageInset: Double = Self.defaultImageInset
    /// Vertical repositioning within the crop, in points — lets the user pan a `.scaledToFill()`
    /// photo up/down instead of always cropping to its center.
    var imageOffsetY: Double = 0
    /// Only used for `.music` content.
    var musicLayout = MusicLayout.disc
    /// Independent of the card's global border — the music art can have its own outline/color.
    var musicBorderEnabled = false
    var musicBorderHex = "FFFFFF"
    /// Independent per-field toggles so the title/artist/album text can be hidden in the Live
    /// Activity while staying visible everywhere else the style is edited/previewed.
    var musicShowsTitle = true
    var musicShowsArtist = true
    var musicShowsAlbum = true
    /// Which side of the card the album art sits on, relative to the title/artist/album text.
    var musicArtPosition = MusicArtPosition.trailing
    /// Local-only UI chrome (the "Enviar" button's tint in the friend-send compose flow) — never
    /// rendered into the Live Activity itself and never sent to a friend, but still lives on the
    /// per-draft style (not shared view @State) so it resets to the default with every other card,
    /// instead of leaking whatever color was last picked into the next card opened.
    var friendSendButtonColorHex = "FFCC00"
    enum MusicArtPosition: String, Codable, CaseIterable, Identifiable {
        case leading, trailing

        var id: Self { self }
        var title: String { self == .leading ? "Left" : "Right" }
    }
    enum MusicLayout: String, Codable, CaseIterable, Identifiable {
        case disc, square, heart, diamond, star

        var id: Self { self }

        var title: String {
            switch self {
            case .disc: "Disc"
            case .square: "Square"
            case .heart: "Heart"
            case .diamond: "Diamond"
            case .star: "Star"
            }
        }

        var clipShape: AnyShape {
            switch self {
            case .disc: AnyShape(Circle())
            case .square: AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .heart: AnyShape(HeartShape())
            case .diamond: AnyShape(DiamondShape())
            case .star: AnyShape(StarShape())
            }
        }
    }
    enum BackgroundMode: String, Codable, CaseIterable, Identifiable { case plain, gradient, image; var id: Self { self }; var title: String { rawValue.capitalized } }
    enum GradientKind: String, Codable, CaseIterable, Identifiable {
        case linear, radial, angular

        var id: Self { self }
        var title: String { rawValue.capitalized }
    }
    enum FontChoice: String, Codable, CaseIterable, Identifiable { case rounded, serif, monospaced; var id: Self { self }; var title: String { rawValue.capitalized } }
    enum TextAlignmentChoice: String, Codable, CaseIterable, Identifiable { case leading, center, trailing; var id: Self { self }; var title: String { rawValue.capitalized } }
    enum VerticalAlignmentChoice: String, Codable, CaseIterable, Identifiable { case top, center, bottom; var id: Self { self }; var title: String { rawValue.capitalized } }
    enum ChecklistScheme: String, Codable, CaseIterable, Identifiable, Hashable {
        case circleCheck, circleCheckPadded, square, squarePadded, heart, star, diamond, flame, tennisball

        var id: Self { self }

        var title: String {
            switch self {
            case .circleCheck: "Circle"
            case .circleCheckPadded: "Circle Padded"
            case .square: "Square"
            case .squarePadded: "Square Padded"
            case .heart: "Heart"
            case .star: "Star"
            case .diamond: "Diamond"
            case .flame: "Flame"
            case .tennisball: "Tennis Ball"
            }
        }

        var emptySymbol: String? {
            switch self {
            case .circleCheck, .circleCheckPadded: nil
            case .square, .squarePadded: "square"
            case .heart: "heart"
            case .star: "star"
            case .diamond: "diamond"
            case .flame: "flame"
            case .tennisball: "tennisball"
            }
        }

        var completedSymbol: String? {
            switch self {
            case .circleCheck, .circleCheckPadded: nil
            case .square, .squarePadded: "square.fill"
            case .heart: "heart.fill"
            case .star: "star.fill"
            case .diamond: "diamond.fill"
            case .flame: "flame.fill"
            case .tennisball: "tennisball.fill"
            }
        }

        var symbolScale: CGFloat {
            switch self {
            case .circleCheckPadded: 0.76
            case .square: 0.82
            case .squarePadded: 0.66
            default: 1
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case backgroundHex, gradientStartHex, gradientEndHex, gradientKind, gradientAngle, gradientCenterX, gradientCenterY, backgroundImageData, backgroundImageURL, backgroundIsCustomized, textHex, backgroundMode, font, textSize, alignment, verticalAlignment, lineSpacingMultiplier, borderHex, borderWidth, checklistScheme, imageInset, imageOffsetY, musicLayout, musicBorderEnabled, musicBorderHex, musicShowsTitle, musicShowsArtist, musicShowsAlbum, musicArtPosition, friendSendButtonColorHex }

    var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var swiftUIVerticalAlignment: VerticalAlignment {
        switch verticalAlignment {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }

    /// The whole content block's position within its card — not just how multiline text wraps
    /// (`textAlignment`), which previously left the content pinned top-leading regardless of what
    /// the user picked here.
    var contentAlignment: Alignment {
        Alignment(horizontal: horizontalAlignment, vertical: swiftUIVerticalAlignment)
    }

    var fontDesign: Font.Design {
        switch font {
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backgroundHex = try container.decodeIfPresent(String.self, forKey: .backgroundHex) ?? "F6F6F7"
        gradientStartHex = try container.decodeIfPresent(String.self, forKey: .gradientStartHex) ?? backgroundHex
        gradientEndHex = try container.decodeIfPresent(String.self, forKey: .gradientEndHex) ?? "D7E6FF"
        gradientKind = try container.decodeIfPresent(GradientKind.self, forKey: .gradientKind) ?? .linear
        gradientAngle = try container.decodeIfPresent(Double.self, forKey: .gradientAngle) ?? 135
        gradientCenterX = try container.decodeIfPresent(Double.self, forKey: .gradientCenterX) ?? 0.5
        gradientCenterY = try container.decodeIfPresent(Double.self, forKey: .gradientCenterY) ?? 0.5
        backgroundImageData = try container.decodeIfPresent(Data.self, forKey: .backgroundImageData)
        backgroundImageURL = try container.decodeIfPresent(String.self, forKey: .backgroundImageURL)
        backgroundIsCustomized = try container.decodeIfPresent(Bool.self, forKey: .backgroundIsCustomized) ?? false
        textHex = try container.decodeIfPresent(String.self, forKey: .textHex) ?? "111111"
        backgroundMode = try container.decodeIfPresent(BackgroundMode.self, forKey: .backgroundMode) ?? .plain
        font = try container.decodeIfPresent(FontChoice.self, forKey: .font) ?? .rounded
        let decodedTextSize = try container.decodeIfPresent(Double.self, forKey: .textSize) ?? Self.defaultTextSize
        textSize = min(Self.maximumTextSize, max(Self.minimumTextSize, decodedTextSize))
        alignment = try container.decodeIfPresent(TextAlignmentChoice.self, forKey: .alignment) ?? .leading
        verticalAlignment = try container.decodeIfPresent(VerticalAlignmentChoice.self, forKey: .verticalAlignment) ?? .center
        lineSpacingMultiplier = try container.decodeIfPresent(Double.self, forKey: .lineSpacingMultiplier) ?? Self.defaultLineSpacingMultiplier
        borderHex = try container.decodeIfPresent(String.self, forKey: .borderHex) ?? "FFFFFF"
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0
        checklistScheme = try container.decodeIfPresent(ChecklistScheme.self, forKey: .checklistScheme) ?? .circleCheck
        imageInset = try container.decodeIfPresent(Double.self, forKey: .imageInset) ?? Self.defaultImageInset
        imageOffsetY = try container.decodeIfPresent(Double.self, forKey: .imageOffsetY) ?? 0
        musicLayout = try container.decodeIfPresent(MusicLayout.self, forKey: .musicLayout) ?? .disc
        musicBorderEnabled = try container.decodeIfPresent(Bool.self, forKey: .musicBorderEnabled) ?? false
        musicBorderHex = try container.decodeIfPresent(String.self, forKey: .musicBorderHex) ?? "FFFFFF"
        musicShowsTitle = try container.decodeIfPresent(Bool.self, forKey: .musicShowsTitle) ?? true
        musicShowsArtist = try container.decodeIfPresent(Bool.self, forKey: .musicShowsArtist) ?? true
        musicShowsAlbum = try container.decodeIfPresent(Bool.self, forKey: .musicShowsAlbum) ?? true
        musicArtPosition = try container.decodeIfPresent(MusicArtPosition.self, forKey: .musicArtPosition) ?? .trailing
        friendSendButtonColorHex = try container.decodeIfPresent(String.self, forKey: .friendSendButtonColorHex) ?? "FFCC00"
    }
}

extension ActivityStyle {
    /// A friend ping's style rides in `FriendActivitySnapshot` (the shared, push-transportable
    /// shape) rather than as a real `ActivityStyle` — this bridges back so the received content
    /// can be rendered/copied/re-edited with the exact same views as any local activity.
    init(snapshot: FriendActivitySnapshot) {
        self.init()
        backgroundHex = snapshot.backgroundHex
        backgroundImageURL = snapshot.imageURL
        backgroundMode = BackgroundMode(rawValue: snapshot.backgroundMode) ?? .plain
        gradientStartHex = snapshot.gradientStartHex
        gradientEndHex = snapshot.gradientEndHex
        gradientKind = GradientKind(rawValue: snapshot.gradientKind) ?? .linear
        gradientAngle = snapshot.gradientAngle
        gradientCenterX = snapshot.gradientCenterX
        gradientCenterY = snapshot.gradientCenterY
        textHex = snapshot.textHex
        font = FontChoice(rawValue: snapshot.font) ?? .rounded
        textSize = snapshot.textSize
        alignment = TextAlignmentChoice(rawValue: snapshot.alignment) ?? .leading
        verticalAlignment = VerticalAlignmentChoice(rawValue: snapshot.verticalAlignment) ?? .center
        lineSpacingMultiplier = snapshot.lineSpacingMultiplier
        borderHex = snapshot.borderHex
        borderWidth = snapshot.borderWidth
        musicLayout = MusicLayout(rawValue: snapshot.musicLayout) ?? .disc
        musicBorderEnabled = snapshot.musicBorderEnabled
        musicBorderHex = snapshot.musicBorderHex
        musicShowsTitle = snapshot.musicShowsTitle
        musicShowsArtist = snapshot.musicShowsArtist
        musicShowsAlbum = snapshot.musicShowsAlbum
        musicArtPosition = MusicArtPosition(rawValue: snapshot.musicArtPosition) ?? .trailing
    }
}

struct LiveActivityDraft: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ActivityKind = .note
    var title = ""
    var body = ""
    var noteIsCompleted = false
    var checklistItems: [ChecklistItem] = [ChecklistItem(text: "")]
    var syncWithReminders = false
    var reminderListID: String?
    var hideCompletedChecklistItems = false
    var liveActionItems: [LiveActionItem] = []
    var tags: [Tag] = []
    var isStrict = false
    var blurContentMode: BlurContentMode = .never
    var isContentBlurred = true
    var style = ActivityStyle()
    var musicTitle = ""
    var musicArtist = ""
    var musicAlbum = ""
    var musicSpotifyTrackID: String?
    /// Universal link (`https://open.spotify.com/track/...`) — routes to the Spotify app if
    /// installed, else the web player. Used everywhere a "play this track" action is needed.
    var musicSpotifyURL: String?
    /// Spotify's CDN art URL — kept alongside `musicAlbumArtData` for paths that can do a live
    /// network fetch (e.g. `AsyncImage` in the received-friend-ping sheet).
    var musicAlbumArtURL: String?
    /// Downloaded once at pick-time, like `ActivityStyle.backgroundImageData` — Live Activity
    /// content must be synchronous/local, no network fetch at render time.
    var musicAlbumArtData: Data?
    var isValid: Bool {
        switch kind {
        case .note:
            !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            style.backgroundImageData != nil
        case .music:
            !musicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .check(.todoList):
            !checklistItems.isEmpty && checklistItems.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .check(.buttons):
            !liveActionItems.isEmpty
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, body, noteIsCompleted, checklistItems, syncWithReminders, reminderListID, hideCompletedChecklistItems, liveActionItems, tags, isStrict, blurContentMode, isContentBlurred, style, musicTitle, musicArtist, musicAlbum, musicSpotifyTrackID, musicSpotifyURL, musicAlbumArtURL, musicAlbumArtData
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(ActivityKind.self, forKey: .kind) ?? .note
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        noteIsCompleted = try container.decodeIfPresent(Bool.self, forKey: .noteIsCompleted) ?? false
        checklistItems = try container.decodeIfPresent([ChecklistItem].self, forKey: .checklistItems) ?? [ChecklistItem(text: "")]
        syncWithReminders = try container.decodeIfPresent(Bool.self, forKey: .syncWithReminders) ?? false
        reminderListID = try container.decodeIfPresent(String.self, forKey: .reminderListID)
        hideCompletedChecklistItems = try container.decodeIfPresent(Bool.self, forKey: .hideCompletedChecklistItems) ?? false
        liveActionItems = try container.decodeIfPresent([LiveActionItem].self, forKey: .liveActionItems) ?? []
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        isStrict = try container.decodeIfPresent(Bool.self, forKey: .isStrict) ?? false
        blurContentMode = try container.decodeIfPresent(BlurContentMode.self, forKey: .blurContentMode) ?? .never
        isContentBlurred = try container.decodeIfPresent(Bool.self, forKey: .isContentBlurred) ?? true
        style = try container.decodeIfPresent(ActivityStyle.self, forKey: .style) ?? ActivityStyle()
        musicTitle = try container.decodeIfPresent(String.self, forKey: .musicTitle) ?? ""
        musicArtist = try container.decodeIfPresent(String.self, forKey: .musicArtist) ?? ""
        musicAlbum = try container.decodeIfPresent(String.self, forKey: .musicAlbum) ?? ""
        musicSpotifyTrackID = try container.decodeIfPresent(String.self, forKey: .musicSpotifyTrackID)
        musicSpotifyURL = try container.decodeIfPresent(String.self, forKey: .musicSpotifyURL)
        musicAlbumArtURL = try container.decodeIfPresent(String.self, forKey: .musicAlbumArtURL)
        musicAlbumArtData = try container.decodeIfPresent(Data.self, forKey: .musicAlbumArtData)
    }

    /// The self-contained payload sent to a friend's device — see `FriendActivitySnapshot`.
    /// `.image` carries a Storage URL (uploaded right before sending — see
    /// CreateActivityV2EditViewModel.send()) instead of raw bytes, the same way `.music` already
    /// carries `musicAlbumArtURL` instead of `musicAlbumArtData`.
    var friendActivitySnapshot: FriendActivitySnapshot {
        if kind == .music {
            return FriendActivitySnapshot(
                kind: "music",
                body: "",
                backgroundHex: style.backgroundHex,
                backgroundMode: style.backgroundMode == .gradient ? "gradient" : "plain",
                gradientStartHex: style.gradientStartHex,
                gradientEndHex: style.gradientEndHex,
                gradientKind: style.gradientKind.rawValue,
                gradientAngle: style.gradientAngle,
                gradientCenterX: style.gradientCenterX,
                gradientCenterY: style.gradientCenterY,
                textHex: style.textHex,
                font: style.font.rawValue,
                textSize: style.textSize,
                alignment: style.alignment.rawValue,
                verticalAlignment: style.verticalAlignment.rawValue,
                lineSpacingMultiplier: style.lineSpacingMultiplier,
                borderHex: style.borderHex,
                borderWidth: style.borderWidth,
                musicTitle: musicTitle,
                musicArtist: musicArtist,
                musicAlbum: musicAlbum,
                musicSpotifyTrackID: musicSpotifyTrackID,
                musicSpotifyURL: musicSpotifyURL,
                musicAlbumArtURL: musicAlbumArtURL,
                musicLayout: style.musicLayout.rawValue,
                musicBorderEnabled: style.musicBorderEnabled,
                musicBorderHex: style.musicBorderHex,
                musicShowsTitle: style.musicShowsTitle,
                musicShowsArtist: style.musicShowsArtist,
                musicShowsAlbum: style.musicShowsAlbum,
                musicArtPosition: style.musicArtPosition.rawValue
            )
        }
        if kind == .image {
            return FriendActivitySnapshot(
                kind: "image",
                body: "",
                backgroundHex: style.backgroundHex,
                backgroundMode: style.backgroundMode == .gradient ? "gradient" : "plain",
                gradientStartHex: style.gradientStartHex,
                gradientEndHex: style.gradientEndHex,
                gradientKind: style.gradientKind.rawValue,
                gradientAngle: style.gradientAngle,
                gradientCenterX: style.gradientCenterX,
                gradientCenterY: style.gradientCenterY,
                textHex: style.textHex,
                font: style.font.rawValue,
                textSize: style.textSize,
                alignment: style.alignment.rawValue,
                verticalAlignment: style.verticalAlignment.rawValue,
                lineSpacingMultiplier: style.lineSpacingMultiplier,
                borderHex: style.borderHex,
                borderWidth: style.borderWidth,
                imageURL: style.backgroundImageURL
            )
        }
        return FriendActivitySnapshot(
            body: body,
            backgroundHex: style.backgroundHex,
            backgroundMode: style.backgroundMode == .gradient ? "gradient" : "plain",
            gradientStartHex: style.gradientStartHex,
            gradientEndHex: style.gradientEndHex,
            gradientKind: style.gradientKind.rawValue,
            gradientAngle: style.gradientAngle,
            gradientCenterX: style.gradientCenterX,
            gradientCenterY: style.gradientCenterY,
            textHex: style.textHex,
            font: style.font.rawValue,
            textSize: style.textSize,
            alignment: style.alignment.rawValue,
            verticalAlignment: style.verticalAlignment.rawValue,
            lineSpacingMultiplier: style.lineSpacingMultiplier,
            borderHex: style.borderHex,
            borderWidth: style.borderWidth
        )
    }
}

extension LiveActivityDraft {
    /// Reconstructs a local, editable draft from a friend's snapshot — used both to render a
    /// received ping through the same views as any local activity (`ActivityPreviewView`) and to
    /// seed a brand-new draft when the user chooses "re-edit" on one. `musicAlbumArtData` is left
    /// nil: a snapshot never carries the raw bytes (too big for the APNs payload), only a URL.
    init(snapshot: FriendActivitySnapshot) {
        self.init()
        kind = snapshot.kind == "music" ? .music : (snapshot.kind == "image" ? .image : .note)
        body = snapshot.body
        style = ActivityStyle(snapshot: snapshot)
        musicTitle = snapshot.musicTitle ?? ""
        musicArtist = snapshot.musicArtist ?? ""
        musicAlbum = snapshot.musicAlbum ?? ""
        musicSpotifyTrackID = snapshot.musicSpotifyTrackID
        musicSpotifyURL = snapshot.musicSpotifyURL
        musicAlbumArtURL = snapshot.musicAlbumArtURL
    }
}

struct ScheduledActivity: Codable, Identifiable, Hashable {
    var id: UUID
    var notificationID: String
    var surface: ActivitySurface
    var draft: LiveActivityDraft
    var startDate: Date
    var endDate: Date?
    var recurrence: Set<Weekday>
    var status: ActivityStatus
    var liveActivityID: String?
    var locationTriggerEnabled = false
    var locationLatitude: Double?
    var locationLongitude: Double?
    var locationRadius: Double = 500
    var createdAt: Date = .now
    /// How long each fired Live Activity instance stays visible before auto-dismissing, capped at
    /// the platform's ~8h Live Activity lifetime. Distinct from `endDate`, which caps how long a
    /// weekly recurrence keeps repeating.
    var autoEndDuration: TimeInterval?
    /// UI placeholder only — not wired to an actual alarm yet.
    var alarmEnabled = false

    init(draft: LiveActivityDraft, surface: ActivitySurface = .liveActivity, startDate: Date, endDate: Date? = nil, recurrence: Set<Weekday> = [], status: ActivityStatus) {
        self.id = draft.id; self.notificationID = draft.id.uuidString; self.surface = surface; self.draft = draft; self.startDate = startDate; self.endDate = endDate; self.recurrence = recurrence; self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, notificationID, surface, draft, startDate, endDate, recurrence, status, liveActivityID, locationTriggerEnabled, locationLatitude, locationLongitude, locationRadius, createdAt, autoEndDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        notificationID = try container.decode(String.self, forKey: .notificationID)
        surface = try container.decodeIfPresent(ActivitySurface.self, forKey: .surface) ?? .liveActivity
        draft = try container.decode(LiveActivityDraft.self, forKey: .draft)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        recurrence = try container.decodeIfPresent(Set<Weekday>.self, forKey: .recurrence) ?? []
        status = try container.decode(ActivityStatus.self, forKey: .status)
        liveActivityID = try container.decodeIfPresent(String.self, forKey: .liveActivityID)
        locationTriggerEnabled = try container.decodeIfPresent(Bool.self, forKey: .locationTriggerEnabled) ?? false
        locationLatitude = try container.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try container.decodeIfPresent(Double.self, forKey: .locationLongitude)
        locationRadius = try container.decodeIfPresent(Double.self, forKey: .locationRadius) ?? 500
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        autoEndDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .autoEndDuration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(notificationID, forKey: .notificationID)
        try container.encode(surface, forKey: .surface)
        try container.encode(draft, forKey: .draft)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(liveActivityID, forKey: .liveActivityID)
        try container.encodeIfPresent(autoEndDuration, forKey: .autoEndDuration)
        try container.encode(locationTriggerEnabled, forKey: .locationTriggerEnabled)
        try container.encodeIfPresent(locationLatitude, forKey: .locationLatitude)
        try container.encodeIfPresent(locationLongitude, forKey: .locationLongitude)
        try container.encode(locationRadius, forKey: .locationRadius)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}

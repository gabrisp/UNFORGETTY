import ActivityKit
import AppIntents
import EventKit
import Foundation
import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

struct WidgetChecklistItem: Codable, Identifiable {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var reminderID: String?
}

struct WidgetLiveActionItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var kind: String
    var icon: String
    var customIcon: String?
    var backgroundHex: String
    var textHex: String
    var target: String
    var shortcutInput: String?
}

struct WidgetTag: Codable, Identifiable {
    var id: UUID
    var name: String
}

/// A friend ping's device has no local draft to read from (`WidgetContentStore` only knows about
/// activities created on that device), so the note's or music track's actual content and style
/// ride along in the push's content-state instead — this is that self-contained snapshot. Only
/// note-kind and music-kind content are supported: raw image bytes would blow the ~4KB APNs
/// content-state limit, so music's album art rides as a URL the receiving widget fetches instead.
struct FriendActivitySnapshot: Codable, Hashable {
    var kind: String = "note"
    var body: String
    var backgroundHex: String
    var backgroundMode: String
    var gradientStartHex: String
    var gradientEndHex: String
    var gradientKind: String
    var gradientAngle: Double
    var gradientCenterX: Double
    var gradientCenterY: Double
    var textHex: String
    var font: String
    var textSize: Double
    var alignment: String
    var verticalAlignment: String = "center"
    var lineSpacingMultiplier: Double = 0.15
    var borderHex: String
    var borderWidth: Double
    var musicTitle: String?
    var musicArtist: String?
    var musicAlbum: String?
    var musicSpotifyTrackID: String?
    var musicSpotifyURL: String?
    var musicAlbumArtURL: String?
    var musicLayout: String = "disc"
    var musicBorderEnabled: Bool = false
    var musicBorderHex: String = "FFFFFF"
    var musicShowsTitle: Bool = true
    var musicShowsArtist: Bool = true
    var musicShowsAlbum: Bool = true
    var musicArtPosition: String = "trailing"
    /// `.image`-kind only — uploaded to the "images" Storage bucket right before sending, since
    /// raw bytes can't fit in the push payload (same reasoning as `musicAlbumArtURL`).
    var imageURL: String?
}

/// A friend ping kept around after it arrives so it can still be opened later — separate from
/// `activities.v1` (the user's own activities) since these were never created on this device.
struct ReceivedFriendPing: Codable, Identifiable {
    var notificationID: String
    var fromUsername: String
    var message: String?
    var snapshot: FriendActivitySnapshot
    var receivedAt: Date
    var id: String { notificationID }
}

struct WidgetStyle: Codable {
    var backgroundHex: String
    var gradientStartHex: String?
    var gradientEndHex: String?
    var gradientKind: String?
    var gradientAngle: Double?
    var gradientCenterX: Double?
    var gradientCenterY: Double?
    var backgroundImageData: Data?
    var textHex: String
    var backgroundMode: String?
    var font: String
    var textSize: Double
    var alignment: String
    var verticalAlignment: String?
    var lineSpacingMultiplier: Double?
    var borderHex: String?
    var borderWidth: Double?
    var checklistScheme: String?
    var imageInset: Double?
    var imageOffsetY: Double?
    var musicLayout: String?
    var musicBorderEnabled: Bool?
    var musicBorderHex: String?
    var musicShowsTitle: Bool?
    var musicShowsArtist: Bool?
    var musicShowsAlbum: Bool?
    var musicArtPosition: String?
}

struct WidgetDraft: Codable {
    var id: UUID?
    var kind: String
    var title: String
    var body: String
    var noteIsCompleted: Bool
    var checklistItems: [WidgetChecklistItem]
    var hideCompletedChecklistItems: Bool?
    var liveActionItems: [WidgetLiveActionItem]?
    var tags: [WidgetTag]?
    var isStrict: Bool
    var blurContentMode: String?
    var isContentBlurred: Bool?
    var style: WidgetStyle
    var musicTitle: String?
    var musicArtist: String?
    var musicAlbum: String?
    var musicSpotifyTrackID: String?
    var musicSpotifyURL: String?
    var musicAlbumArtURL: String?
    var musicAlbumArtData: Data?
}

struct WidgetActivity: Codable {
    var id: UUID
    var notificationID: String
    var surface: String?
    var draft: WidgetDraft
    var startDate: Date?
    var endDate: Date?
    var recurrence: Set<Int>?
    var status: String?
    var liveActivityID: String?
    var createdAt: Date?
}

/// Music art clip shapes. Kept here (rather than in Models.swift, which is app-only) since it
/// compiles into both the app and widget targets — the widget resolves `musicLayout` from a raw
/// string, the app from `ActivityStyle.MusicLayout`, but both need the same geometry.
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.94))
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.24),
            control1: CGPoint(x: w * 0.5, y: h * 0.72),
            control2: CGPoint(x: 0, y: h * 0.52)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.14),
            control1: CGPoint(x: 0, y: h * 0.02),
            control2: CGPoint(x: w * 0.32, y: -h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.24),
            control1: CGPoint(x: w * 0.68, y: -h * 0.02),
            control2: CGPoint(x: w, y: h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.94),
            control1: CGPoint(x: w, y: h * 0.52),
            control2: CGPoint(x: w * 0.5, y: h * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = 5
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

nonisolated enum LiveActionURLBuilder {
    static func url(kind: String, target: String, shortcutInput: String? = nil) -> URL? {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else { return nil }

        switch kind {
        case "shortcut":
            var components = URLComponents()
            components.scheme = "shortcuts"
            components.host = "run-shortcut"
            var queryItems = [URLQueryItem(name: "name", value: trimmedTarget)]

            if let shortcutInput = shortcutInput?.trimmingCharacters(in: .whitespacesAndNewlines), !shortcutInput.isEmpty {
                queryItems.append(URLQueryItem(name: "input", value: "text"))
                queryItems.append(URLQueryItem(name: "text", value: shortcutInput))
            }

            // iOS has no way to run a user's Shortcut without the Shortcuts app itself briefly
            // taking over to interpret it — these x-callback-url params are the closest available
            // mitigation: they make it hand focus straight back to Unforgetty the moment the
            // shortcut finishes (or is cancelled/errors), instead of leaving the user stranded in
            // the Shortcuts app.
            queryItems.append(URLQueryItem(name: "x-success", value: "unforgetty://shortcut-completed"))
            queryItems.append(URLQueryItem(name: "x-cancel", value: "unforgetty://shortcut-completed"))
            queryItems.append(URLQueryItem(name: "x-error", value: "unforgetty://shortcut-completed"))

            components.queryItems = queryItems
            return components.url
        case "openApp":
            if trimmedTarget.contains(":") {
                return URL(string: trimmedTarget)
            }

            return URL(string: "\(trimmedTarget)://")
        default:
            if trimmedTarget.contains("://") {
                return URL(string: trimmedTarget)
            }

            return URL(string: "https://\(trimmedTarget)")
        }
    }
}

nonisolated struct LiveActivityReferenceEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Live Activity")
    static var defaultQuery = LiveActivityReferenceQuery()

    let id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Live Activity")
    }
}

nonisolated struct LiveActivityReferenceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LiveActivityReferenceEntity] {
        identifiers.map { LiveActivityReferenceEntity(id: $0) }
    }
}

nonisolated struct ChecklistItemReferenceEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Checklist Item")
    static var defaultQuery = ChecklistItemReferenceQuery()

    let id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Checklist Item")
    }
}

nonisolated struct ChecklistItemReferenceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ChecklistItemReferenceEntity] {
        identifiers.map { ChecklistItemReferenceEntity(id: $0) }
    }
}

/// Large image bytes (background photos, music album art) live as files in the App Group
/// container instead of embedded as base64 inside the `"activities.v1"` JSON blob. That blob gets
/// fully re-decoded on every single Live Activity render pass (lock screen, each Dynamic Island
/// region is a separate pass) and fully re-encoded on every app-side save — inflating it with
/// base64 image data made it balloon fast and made images unreliable to persist/render under the
/// widget extension's tight memory budget. Keyed by `notificationID`, which both `ScheduledActivity`
/// and `WidgetActivity` carry, so app and widget agree on the filename without extra bookkeeping.
nonisolated enum SharedImageStore {
    private static let directoryURL: URL? = {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gabrisp.Unforgetty") else { return nil }
        let dir = container.appendingPathComponent("SharedImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save(_ data: Data?, name: String) {
        guard let url = directoryURL?.appendingPathComponent(name) else { return }
        guard let data else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    static func load(name: String) -> Data? {
        guard let url = directoryURL?.appendingPathComponent(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func deleteAll(notificationID: String) {
        save(nil, name: "\(notificationID)-bg.jpg")
        save(nil, name: "\(notificationID)-music.jpg")
    }
}

/// Background/album-art images are stored as raw `Data` on the draft and decoded into `UIImage`
/// via a plain computed property wherever they're rendered — which SwiftUI re-evaluates on every
/// single body pass, including every frame of a `withAnimation` transition (the card-open/close
/// animation runs at up to 60fps). Redecoding a JPEG from bytes on every one of those frames is
/// real, easily-felt CPU cost and the direct cause of the animation getting laggier/glitchier the
/// more images have been opened in a session. Keyed by the raw bytes themselves (`NSData` hashes/
/// equates by content) rather than any app-specific ID, so it works for every caller — the app's
/// own drafts, the widget's, and a friend snapshot's downloaded art — without extra plumbing.
/// `NSCache` evicts under memory pressure on its own, so this never needs manual invalidation.
#if canImport(UIKit)
nonisolated enum ImageDecodeCache {
    private static let cache = NSCache<NSData, UIImage>()

    static func image(for data: Data) -> UIImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let decoded = UIImage(data: data) else { return nil }
        cache.setObject(decoded, forKey: key, cost: data.count)
        return decoded
    }
}
#endif

nonisolated enum WidgetContentStore {
    static let defaults = UserDefaults(suiteName: "group.com.gabrisp.Unforgetty") ?? .standard

    private static let pendingExternalLinkKey = "pendingExternalLink.v1"

    /// A Live Activity's `.widgetURL(_:)` only ever routes back into the containing app — it can't
    /// open a different app (Spotify, Shortcuts, ...), and an interactive `Button(intent:)` whose
    /// result chains into `OpenURLIntent` is not reliable for that either from a `LiveActivityIntent`
    /// context. The mechanism that *does* work: the intent sets `openAppWhenRun = true` (guaranteeing
    /// the app launches/foregrounds), stashes the real target URL here, and the app itself — which
    /// has a full, unconstrained process — opens it via `openURL` on the next launch/foreground.
    /// See PendingExternalLinkOpener in UnforgettyApp.swift for the read side.
    static func setPendingExternalLink(_ urlString: String) {
        defaults.set(urlString, forKey: pendingExternalLinkKey)
    }

    static func consumePendingExternalLink() -> URL? {
        guard let urlString = defaults.string(forKey: pendingExternalLinkKey) else { return nil }
        defaults.removeObject(forKey: pendingExternalLinkKey)
        return URL(string: urlString)
    }

    static func draft(for notificationID: String) -> WidgetDraft? {
        guard let data = defaults.data(forKey: "activities.v1") else { return nil }
        guard let values = try? JSONDecoder().decode([WidgetActivity].self, from: data) else { return nil }
        guard var draft = values.first(where: { $0.notificationID == notificationID })?.draft else { return nil }

        // Image bytes are never embedded in this JSON blob (see SharedImageStore) — only this one
        // activity's images get loaded from disk, not every saved activity's.
        draft.style.backgroundImageData = SharedImageStore.load(name: "\(notificationID)-bg.jpg")
        draft.musicAlbumArtData = SharedImageStore.load(name: "\(notificationID)-music.jpg")
        return draft
    }

    private static let receivedFriendPingsKey = "receivedFriendPings.v1"

    /// Idempotent by `notificationID` — the widget calls this from `.onAppear`, which can fire
    /// more than once for the same push.
    static func saveReceivedFriendPing(notificationID: String, fromUsername: String, message: String?, snapshot: FriendActivitySnapshot) {
        var pings = receivedFriendPings()
        guard !pings.contains(where: { $0.notificationID == notificationID }) else { return }
        pings.insert(ReceivedFriendPing(notificationID: notificationID, fromUsername: fromUsername, message: message, snapshot: snapshot, receivedAt: .now), at: 0)
        defaults.set(try? JSONEncoder().encode(pings), forKey: receivedFriendPingsKey)
    }

    static func receivedFriendPings() -> [ReceivedFriendPing] {
        guard
            let data = defaults.data(forKey: receivedFriendPingsKey),
            let pings = try? JSONDecoder().decode([ReceivedFriendPing].self, from: data)
        else { return [] }
        return pings
    }

    /// Album art for a music friend-ping arrives asynchronously (fetched by the widget from
    /// `musicAlbumArtURL` after the initial synchronous `saveReceivedFriendPing`) — stored as its
    /// own key rather than patched into the pings array to avoid a read-modify-write race.
    static func saveMusicAlbumArt(notificationID: String, data: Data) {
        defaults.set(data, forKey: "musicArt.\(notificationID)")
    }

    static func musicAlbumArt(notificationID: String) -> Data? {
        defaults.data(forKey: "musicArt.\(notificationID)")
    }

    static func receivedFriendPing(notificationID: String) -> ReceivedFriendPing? {
        receivedFriendPings().first { $0.notificationID == notificationID }
    }

    static func deleteReceivedFriendPing(notificationID: String) {
        var pings = receivedFriendPings()
        guard pings.contains(where: { $0.notificationID == notificationID }) else { return }
        pings.removeAll { $0.notificationID == notificationID }
        defaults.set(try? JSONEncoder().encode(pings), forKey: receivedFriendPingsKey)
        defaults.removeObject(forKey: "musicArt.\(notificationID)")
    }

    /// `saveReceivedFriendPing` is deliberately insert-only (idempotent against the widget calling
    /// it repeatedly for the same push) — it never applies a *later* `.update` push's changed
    /// content onto an already-stored ping. This is the explicit "pull the latest state" path,
    /// used by the app's own "reload" action against whatever's currently running.
    static func updateReceivedFriendPing(notificationID: String, fromUsername: String, message: String?, snapshot: FriendActivitySnapshot) {
        var pings = receivedFriendPings()
        guard let index = pings.firstIndex(where: { $0.notificationID == notificationID }) else { return }
        pings[index] = ReceivedFriendPing(notificationID: notificationID, fromUsername: fromUsername, message: message, snapshot: snapshot, receivedAt: pings[index].receivedAt)
        defaults.set(try? JSONEncoder().encode(pings), forKey: receivedFriendPingsKey)
    }

    static func toggle(itemID: UUID, notificationID: String) -> (reminderID: String, isCompleted: Bool)? {
        var reminder: (String, Bool)?
        updateActivity(notificationID: notificationID) { activity in
            guard let item = activity.draft.checklistItems.firstIndex(where: { $0.id == itemID }) else { return }
            activity.draft.checklistItems[item].isCompleted.toggle()
            if let reminderID = activity.draft.checklistItems[item].reminderID {
                reminder = (reminderID, activity.draft.checklistItems[item].isCompleted)
            }
        }
        return reminder
    }

    static func remove(itemID: UUID, notificationID: String) {
        updateActivity(notificationID: notificationID) { activity in
            guard activity.draft.checklistItems.count > 1 else { return }
            activity.draft.checklistItems.removeAll { $0.id == itemID }
        }
    }

    static func completeNote(notificationID: String) {
        updateActivity(notificationID: notificationID) { activity in
            activity.draft.noteIsCompleted = true
        }
    }

    static func toggleTapBlur(notificationID: String) {
        updateActivity(notificationID: notificationID) { activity in
            activity.draft.isContentBlurred = !(activity.draft.isContentBlurred ?? true)
        }
    }

    /// A friend ping with a message starts behind a "Mensaje / de @username / Ver" teaser rather
    /// than showing the real content immediately — this tracks which pings have been revealed.
    /// Not stored on `WidgetActivity` like the flags above since a friend ping has no local draft
    /// (see `FriendActivitySnapshot`'s doc comment); insert-only, there's no un-reveal.
    private static let revealedFriendMessagesKey = "revealedFriendMessages.v1"

    static func isFriendMessageRevealed(notificationID: String) -> Bool {
        (defaults.stringArray(forKey: revealedFriendMessagesKey) ?? []).contains(notificationID)
    }

    static func revealFriendMessage(notificationID: String) {
        var ids = Set(defaults.stringArray(forKey: revealedFriendMessagesKey) ?? [])
        guard ids.insert(notificationID).inserted else { return }
        defaults.set(Array(ids), forKey: revealedFriendMessagesKey)
        defaults.synchronize()
    }

    private static func updateActivity(notificationID: String, mutate: (inout WidgetActivity) -> Void) {
        guard
            let data = defaults.data(forKey: "activities.v1"),
            var values = try? JSONDecoder().decode([WidgetActivity].self, from: data),
            let index = values.firstIndex(where: { $0.notificationID == notificationID })
        else { return }

        mutate(&values[index])
        defaults.set(try? JSONEncoder().encode(values), forKey: "activities.v1")
        defaults.synchronize()
    }
}

@MainActor
enum WidgetRemindersStore {
    private static let eventStore = EKEventStore()

    static func setCompleted(_ isCompleted: Bool, reminderID: String) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else { return }
        reminder.isCompleted = isCompleted
        try? eventStore.save(reminder, commit: true)
    }
}

nonisolated enum WidgetLiveActivityRefresher {
    /// Bumps `phase` on the activity's *current* content state rather than constructing a blank
    /// one — a friend ping's content (`fromUsername`/`message`/`friendSnapshot`) lives entirely in
    /// the content state (see `FriendActivitySnapshot`'s doc comment), so rebuilding from scratch
    /// would silently wipe it on every refresh.
    static func refresh(notificationID: String) async {
        let matching = Activity<UnforgettyActivityAttributes>.activities.filter { $0.attributes.notificationID == notificationID }
        for activity in matching {
            var state = activity.content.state
            state.phase = UUID().uuidString
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

nonisolated struct RunLiveActionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ejecutar acción"
    // `true` so tapping the tile reliably launches/foregrounds the app — see
    // WidgetContentStore.setPendingExternalLink's doc comment for why this, rather than chaining
    // straight to OpenURLIntent, is what actually gets the target URL (shortcuts://, a website, ...)
    // to open.
    static var openAppWhenRun = true

    @Parameter(title: "Tipo") var kind: String
    @Parameter(title: "Destino") var target: String
    @Parameter(title: "Entrada") var shortcutInput: String

    init() {
        kind = ""
        target = ""
        shortcutInput = ""
    }

    init(item: WidgetLiveActionItem) {
        kind = item.kind
        target = item.target
        shortcutInput = item.shortcutInput ?? ""
    }

    func perform() async throws -> some IntentResult {
        if let url = LiveActionURLBuilder.url(
            kind: kind,
            target: target,
            shortcutInput: shortcutInput.isEmpty ? nil : shortcutInput
        ) {
            WidgetContentStore.setPendingExternalLink(url.absoluteString)
        }
        return .result()
    }
}

/// Opens a plain URL (e.g. a Spotify track link) from a Live Activity tap — same
/// launch-then-relay mechanism as RunLiveActionIntent above, kept as its own intent since its only
/// input is a raw URL string rather than a live-action item's kind/target/shortcutInput shape.
nonisolated struct OpenExternalLinkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Abrir enlace"
    static var openAppWhenRun = true

    @Parameter(title: "URL") var urlString: String

    init() {
        urlString = ""
    }

    init(urlString: String) {
        self.urlString = urlString
    }

    func perform() async throws -> some IntentResult {
        if !urlString.isEmpty {
            WidgetContentStore.setPendingExternalLink(urlString)
        }
        return .result()
    }
}

nonisolated struct ToggleChecklistItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Completar tarea"
    static var openAppWhenRun = false

    @Parameter(title: "Actividad") var activity: LiveActivityReferenceEntity
    @Parameter(title: "Tarea") var item: ChecklistItemReferenceEntity

    init() {
        activity = LiveActivityReferenceEntity(id: "")
        item = ChecklistItemReferenceEntity(id: "")
    }

    init(notificationID: String, itemID: UUID) {
        activity = LiveActivityReferenceEntity(id: notificationID)
        item = ChecklistItemReferenceEntity(id: itemID.uuidString)
    }

    func perform() async throws -> some IntentResult {
        guard let itemID = UUID(uuidString: item.id) else { return .result() }
        if let reminder = WidgetContentStore.toggle(itemID: itemID, notificationID: activity.id) {
            await WidgetRemindersStore.setCompleted(reminder.isCompleted, reminderID: reminder.reminderID)
        }
        await WidgetLiveActivityRefresher.refresh(notificationID: activity.id)
        return .result()
    }
}

nonisolated struct RemoveChecklistItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Eliminar tarea"
    static var openAppWhenRun = false

    @Parameter(title: "Actividad") var activity: LiveActivityReferenceEntity
    @Parameter(title: "Tarea") var item: ChecklistItemReferenceEntity

    init() {
        activity = LiveActivityReferenceEntity(id: "")
        item = ChecklistItemReferenceEntity(id: "")
    }

    init(notificationID: String, itemID: UUID) {
        activity = LiveActivityReferenceEntity(id: notificationID)
        item = ChecklistItemReferenceEntity(id: itemID.uuidString)
    }

    func perform() async throws -> some IntentResult {
        guard let itemID = UUID(uuidString: item.id) else { return .result() }
        WidgetContentStore.remove(itemID: itemID, notificationID: activity.id)
        await WidgetLiveActivityRefresher.refresh(notificationID: activity.id)
        return .result()
    }
}

nonisolated struct CompleteNoteIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Marcar nota como hecha"
    static var openAppWhenRun = false

    @Parameter(title: "Actividad") var activity: LiveActivityReferenceEntity

    init() {
        activity = LiveActivityReferenceEntity(id: "")
    }

    init(notificationID: String) {
        activity = LiveActivityReferenceEntity(id: notificationID)
    }

    func perform() async throws -> some IntentResult {
        WidgetContentStore.completeNote(notificationID: activity.id)
        await WidgetLiveActivityRefresher.refresh(notificationID: activity.id)
        return .result()
    }
}

nonisolated struct ToggleBlurIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Alternar blur"
    static var openAppWhenRun = false

    @Parameter(title: "Actividad") var activity: LiveActivityReferenceEntity

    init() {
        activity = LiveActivityReferenceEntity(id: "")
    }

    init(notificationID: String) {
        activity = LiveActivityReferenceEntity(id: notificationID)
    }

    func perform() async throws -> some IntentResult {
        WidgetContentStore.toggleTapBlur(notificationID: activity.id)
        await WidgetLiveActivityRefresher.refresh(notificationID: activity.id)
        return .result()
    }
}

nonisolated struct RevealFriendMessageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ver mensaje"
    static var openAppWhenRun = false

    @Parameter(title: "Actividad") var activity: LiveActivityReferenceEntity

    init() {
        activity = LiveActivityReferenceEntity(id: "")
    }

    init(notificationID: String) {
        activity = LiveActivityReferenceEntity(id: notificationID)
    }

    func perform() async throws -> some IntentResult {
        WidgetContentStore.revealFriendMessage(notificationID: activity.id)
        await WidgetLiveActivityRefresher.refresh(notificationID: activity.id)
        return .result()
    }
}

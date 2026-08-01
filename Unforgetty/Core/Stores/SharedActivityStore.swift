import Foundation

/// Shared, content-bearing local store. Only the app group ever contains note text, lists, tags or styles.
enum SharedActivityStore {
    static let suiteName = "group.com.gabrisp.Unforgetty"
    private static let activitiesKey = "activities.v1"
    static var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    static func load() -> [ScheduledActivity] {
        guard let data = defaults.data(forKey: activitiesKey) else { return [] }
        var activities = (try? JSONDecoder().decode([ScheduledActivity].self, from: data)) ?? []
        // Image bytes are stored as files (see SharedImageStore), never inline in this blob —
        // backfill them onto the in-memory drafts so every other app-side call site can keep
        // reading `style.backgroundImageData`/`musicAlbumArtData` directly, unchanged.
        for index in activities.indices {
            let notificationID = activities[index].notificationID
            activities[index].draft.style.backgroundImageData = SharedImageStore.load(name: "\(notificationID)-bg.jpg")
            activities[index].draft.musicAlbumArtData = SharedImageStore.load(name: "\(notificationID)-music.jpg")
        }
        return activities
    }

    static func save(_ activities: [ScheduledActivity]) {
        // Strip image bytes out before encoding — embedding base64 images in this single JSON blob
        // is what made it balloon and made images unreliable to persist/render in the widget
        // extension (fully re-decoded on every render pass under its tight memory budget).
        var stripped = activities
        for index in stripped.indices {
            let notificationID = stripped[index].notificationID
            SharedImageStore.save(stripped[index].draft.style.backgroundImageData, name: "\(notificationID)-bg.jpg")
            SharedImageStore.save(stripped[index].draft.musicAlbumArtData, name: "\(notificationID)-music.jpg")
            stripped[index].draft.style.backgroundImageData = nil
            stripped[index].draft.musicAlbumArtData = nil
        }
        defaults.set(try? JSONEncoder().encode(stripped), forKey: activitiesKey)
    }

    static func activity(notificationID: String) -> ScheduledActivity? {
        load().first { $0.notificationID == notificationID }
    }
}

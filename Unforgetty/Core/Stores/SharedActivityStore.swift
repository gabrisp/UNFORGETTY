import Foundation

/// Shared, content-bearing local store. Only the app group ever contains note text, lists, tags or styles.
enum SharedActivityStore {
    static let suiteName = "group.com.gabrisp.Unforgetty"
    private static let activitiesKey = "activities.v1"
    static var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    static func load() -> [ScheduledActivity] {
        guard let data = defaults.data(forKey: activitiesKey) else { return [] }
        return (try? JSONDecoder().decode([ScheduledActivity].self, from: data)) ?? []
    }
    static func save(_ activities: [ScheduledActivity]) {
        defaults.set(try? JSONEncoder().encode(activities), forKey: activitiesKey)
    }
    static func activity(notificationID: String) -> ScheduledActivity? {
        load().first { $0.notificationID == notificationID }
    }
}

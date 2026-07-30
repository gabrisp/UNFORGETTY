import ActivityKit
import Foundation

struct UnforgettyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var phase: String; var notificationID: String }
    var notificationID: String
}

@MainActor
enum LiveActivityController {
    static func start(_ scheduled: ScheduledActivity) async throws -> String {
        let attributes = UnforgettyActivityAttributes(notificationID: scheduled.notificationID)
        let content = ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: "active", notificationID: scheduled.notificationID), staleDate: scheduled.endDate)
        let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        return activity.id
    }
    static func end(id: String) async {
        guard let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: "ended", notificationID: activity.attributes.notificationID), staleDate: nil), dismissalPolicy: .immediate)
    }

    /// The Live Activity's content lives in the shared App Group store, not in `ContentState`.
    /// Bumping `phase` just forces WidgetKit to re-render from the freshly saved content.
    static func refresh(id: String) async {
        guard let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: UUID().uuidString, notificationID: activity.attributes.notificationID), staleDate: nil))
    }
}

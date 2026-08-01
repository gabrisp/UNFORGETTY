import ActivityKit
import Foundation
#if canImport(UIKit)
import UserNotifications
#endif

struct UnforgettyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var notificationID: String
        // Present only for a friend-sent ping, which has no local draft to read content from —
        // the widget renders this directly instead of looking up WidgetContentStore.
        var fromUsername: String? = nil
        var message: String? = nil
        var friendSnapshot: FriendActivitySnapshot? = nil
    }
    var notificationID: String
}

@MainActor
enum LiveActivityController {
    private static var pushToStartTokenTask: Task<Void, Never>?
    private static let pushTokenKey = "liveactivity.pushToStartToken"

    static func observePushToStartToken() {
        guard pushToStartTokenTask == nil else { return }

        pushToStartTokenTask = Task {
            guard #available(iOS 17.2, *) else { return }
            for await token in Activity<UnforgettyActivityAttributes>.pushToStartTokenUpdates {
                let value = token.map { String(format: "%02x", $0) }.joined()
                UserDefaults(suiteName: "group.com.gabrisp.Unforgetty")?.set(value, forKey: pushTokenKey)
                // So friends can ping this device even if it never registers a schedule of its own.
                try? await SocialRepository.shared.updatePushToken(value)
            }
        }
    }

    static func pushToStartToken() -> String? {
        UserDefaults(suiteName: "group.com.gabrisp.Unforgetty")?.string(forKey: pushTokenKey)
    }

    /// Actively waits for a push-to-start token instead of just reporting whatever's cached —
    /// call this right before scheduling, not only at app launch, so re-enabling notifications
    /// later actually unblocks scheduling instead of leaving it permanently broken.
    static func ensurePushToStartToken(timeout: TimeInterval = 6) async -> String? {
        if let cached = pushToStartToken() { return cached }
        #if canImport(UIKit)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return nil }
        #endif
        observePushToStartToken()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let token = pushToStartToken() { return token }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return pushToStartToken()
    }

    static func start(_ scheduled: ScheduledActivity) async throws -> String {
        let attributes = UnforgettyActivityAttributes(notificationID: scheduled.notificationID)
        let staleDate = scheduled.autoEndDuration.map { Date.now.addingTimeInterval(min($0, Self.maxAutoEndDuration)) }
        let content = ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: "active", notificationID: scheduled.notificationID), staleDate: staleDate)
        let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        return activity.id
    }

    /// The Live Activity platform's own soft cap on how long content stays fresh.
    static let maxAutoEndDuration: TimeInterval = 8 * 3600
    static func end(id: String) async {
        guard let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: "ended", notificationID: activity.attributes.notificationID), staleDate: nil), dismissalPolicy: .default)
    }

    /// The Live Activity's content lives in the shared App Group store, not in `ContentState`.
    /// Bumping `phase` just forces WidgetKit to re-render from the freshly saved content.
    static func refresh(id: String) async {
        guard let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: UUID().uuidString, notificationID: activity.attributes.notificationID), staleDate: nil))
    }
}

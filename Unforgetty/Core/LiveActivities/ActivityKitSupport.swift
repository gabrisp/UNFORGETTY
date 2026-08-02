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
    private static var friendPingUpdateTokenTask: Task<Void, Never>?
    private static var trackedFriendPingIDs: Set<String> = []

    /// Friend-ping activities arrive via push-to-start on the recipient's device, so `start(_:)`
    /// below (used only for this device's own local schedules) never runs for them. Each running
    /// activity's per-instance update token has to be captured separately from the device-wide
    /// pushToStartToken — that one only lets a sender create new activities, never update one
    /// that's already running. Covers both activities already running at launch and ones that
    /// start while the app stays open.
    static func observeFriendPingUpdateTokens() {
        guard friendPingUpdateTokenTask == nil else { return }

        friendPingUpdateTokenTask = Task {
            guard #available(iOS 16.2, *) else { return }
            for activity in Activity<UnforgettyActivityAttributes>.activities {
                trackFriendPingUpdateToken(for: activity)
            }
            for await activity in Activity<UnforgettyActivityAttributes>.activityUpdates {
                trackFriendPingUpdateToken(for: activity)
            }
        }
    }

    private static func trackFriendPingUpdateToken(for activity: Activity<UnforgettyActivityAttributes>) {
        let notificationID = activity.attributes.notificationID
        guard activity.content.state.fromUsername != nil, !trackedFriendPingIDs.contains(notificationID) else { return }
        trackedFriendPingIDs.insert(notificationID)

        Task {
            for await token in activity.pushTokenUpdates {
                let value = token.map { String(format: "%02x", $0) }.joined()
                try? await SocialRepository.shared.registerActivityUpdateToken(
                    notificationID: notificationID,
                    activityUpdateToken: value,
                    message: activity.content.state.message
                )
            }
        }
    }

    static func observePushToStartToken() {
        guard pushToStartTokenTask == nil else { return }

        pushToStartTokenTask = Task {
            guard #available(iOS 17.2, *) else { return }
            for await token in Activity<UnforgettyActivityAttributes>.pushToStartTokenUpdates {
                let value = token.map { String(format: "%02x", $0) }.joined()
                UserDefaults(suiteName: "group.com.gabrisp.Unforgetty")?.set(value, forKey: pushTokenKey)
                print("Unforgetty: got pushToStartTokenUpdates, syncing to backend")
                // So friends can ping this device even if it never registers a schedule of its own.
                // Was previously a silent `try?` — the backend no-ops this (no error) if this
                // device's Profile document doesn't exist yet (e.g. this token can arrive before
                // the user has claimed a username during onboarding), which permanently left
                // friends unable to ping until SocialSettingsModel's own re-sync-on-claim/refresh
                // safety net was added. Logging the outcome so a future silent-drop is visible.
                do {
                    try await SocialRepository.shared.updatePushToken(value)
                    print("Unforgetty: updatePushToken succeeded")
                } catch {
                    print("Unforgetty: updatePushToken FAILED: \(error)")
                }
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

    /// Fallback path for when the recipient has no `pushToStartToken` registered (see
    /// AppwriteFunctions/social's sendFriendPingWakePush) — the backend instead sends a plain
    /// silent push to this device's already-registered general push target, which wakes the app
    /// and hands this off to start the activity itself, in-process, exactly like push-to-start
    /// would have done remotely. Called from UnforgettyAppDelegate's
    /// didReceiveRemoteNotification. Requesting with `pushType: .token` (not nil) still lets
    /// observeFriendPingUpdateTokens() pick up this activity's per-instance update token for
    /// later resends, same as any other friend-ping activity.
    static func startFriendPing(from payload: [AnyHashable: Any]) -> Bool {
        guard
            let info = payload["startFriendPing"] as? [String: Any],
            let notificationID = info["notificationID"] as? String,
            let fromUsername = info["fromUsername"] as? String,
            let snapshotDict = info["snapshot"] as? [String: Any],
            let snapshotData = try? JSONSerialization.data(withJSONObject: snapshotDict),
            let snapshot = try? JSONDecoder().decode(FriendActivitySnapshot.self, from: snapshotData)
        else { return false }
        let message = info["message"] as? String

        let attributes = UnforgettyActivityAttributes(notificationID: notificationID)
        let content = ActivityContent(
            state: UnforgettyActivityAttributes.ContentState(phase: "active", notificationID: notificationID, fromUsername: fromUsername, message: message, friendSnapshot: snapshot),
            staleDate: Date.now.addingTimeInterval(3600)
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: .token)
            return true
        } catch {
            return false
        }
    }

    static func start(_ scheduled: ScheduledActivity) async throws -> String {
        let attributes = UnforgettyActivityAttributes(notificationID: scheduled.notificationID)
        let staleDate = scheduled.autoEndDuration.map { Date.now.addingTimeInterval(min($0, Self.maxAutoEndDuration)) }
        let content = ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: "active", notificationID: scheduled.notificationID), staleDate: staleDate)
        let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        // Confirmed via device logs: the very first render can fire before the widget extension
        // has picked up files just written to the App Group container — the write succeeds, but
        // the first paint's read of it never even gets attempted. Force one more render shortly
        // after so it's guaranteed to re-read with everything already in place.
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await refresh(id: activity.id)
        }
        return activity.id
    }

    /// The Live Activity platform's own soft cap on how long content stays fresh.
    static let maxAutoEndDuration: TimeInterval = 8 * 3600
    static func end(id: String) async {
        guard let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        // `.default` only marks the activity "ended" and lets the system decide when to actually
        // remove it from the Lock Screen — it can stay visible for up to 4 hours. `.immediate` is
        // what makes a delete/kill actually disappear right away.
        await activity.end(ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: "ended", notificationID: activity.attributes.notificationID), staleDate: nil), dismissalPolicy: .immediate)
    }

    /// The Live Activity's content lives in the shared App Group store, not in `ContentState`.
    /// Bumping `phase` just forces WidgetKit to re-render from the freshly saved content.
    static func refresh(id: String) async {
        guard let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.id == id }) else {
            NSLog("Unforgetty LiveActivityController.refresh: no running activity found with id=%@ (total running=%d)", id, Activity<UnforgettyActivityAttributes>.activities.count)
            return
        }
        NSLog("Unforgetty LiveActivityController.refresh: bumping phase for id=%@ notificationID=%@", id, activity.attributes.notificationID)
        await activity.update(ActivityContent(state: UnforgettyActivityAttributes.ContentState(phase: UUID().uuidString, notificationID: activity.attributes.notificationID), staleDate: nil))
        NSLog("Unforgetty LiveActivityController.refresh: activity.update() returned for id=%@", id)
    }
}

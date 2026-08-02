import ActivityKit
import Combine
import Foundation

/// Owns the received-pings data + selection for FriendCardsSection, mirroring the existing
/// CreateActivityV2EditViewModel pattern (data + logic in a view model, not raw @State scattered
/// across the view) rather than duplicating that shape inline in the view struct.
@MainActor
final class FriendCardsViewModel: ObservableObject {
    @Published private(set) var receivedPings: [ReceivedFriendPing] = []
    @Published private(set) var selectedFriendPing: ReceivedFriendPing?
    @Published private(set) var selectedFriendCardHeight: CGFloat = 160

    func load() {
        receivedPings = WidgetContentStore.receivedFriendPings()
        if let selectedFriendPing {
            self.selectedFriendPing = receivedPings.first { $0.notificationID == selectedFriendPing.notificationID }
        }
    }

    func select(_ ping: ReceivedFriendPing, height: CGFloat) {
        selectedFriendPing = ping
        selectedFriendCardHeight = height
    }

    /// The selected card's content can keep changing height while it's open (album art finishing
    /// an async load) — kept separate from `select` since it fires repeatedly, not once.
    func updateCurrentHeight(_ height: CGFloat) {
        selectedFriendCardHeight = height
    }

    func close() {
        selectedFriendPing = nil
    }

    /// `saveReceivedFriendPing` only ever writes once (idempotent against the widget's repeated
    /// `.onAppear`), so a later `.update` push's changed content never lands here on its own —
    /// this pulls the latest state from whatever Live Activity is actually still running.
    func reload(_ ping: ReceivedFriendPing) {
        if
            let activity = Activity<UnforgettyActivityAttributes>.activities.first(where: { $0.attributes.notificationID == ping.notificationID }),
            let fromUsername = activity.content.state.fromUsername,
            let snapshot = activity.content.state.friendSnapshot
        {
            WidgetContentStore.updateReceivedFriendPing(notificationID: ping.notificationID, fromUsername: fromUsername, message: activity.content.state.message, snapshot: snapshot)
        }
        load()
    }

    /// `store` is taken per-call (not stored) to match CreateActivityV2EditViewModel.saveDraft(store:)'s
    /// existing convention in this codebase.
    func copy(_ ping: ReceivedFriendPing, store: ActivityStore) {
        store.copiedEditions = ActivityEditionsClipboard(snapshot: ping.snapshot)
    }

    @discardableResult
    func reedit(_ ping: ReceivedFriendPing, store: ActivityStore) -> ScheduledActivity {
        let activity = ScheduledActivity(draft: LiveActivityDraft(snapshot: ping.snapshot), surface: .liveActivity, startDate: .now, status: .draft)
        store.save(activity)
        selectedFriendPing = nil
        return activity
    }

    func delete(_ ping: ReceivedFriendPing) {
        if selectedFriendPing?.notificationID == ping.notificationID {
            selectedFriendPing = nil
        }
        WidgetContentStore.deleteReceivedFriendPing(notificationID: ping.notificationID)
        load()
    }
}

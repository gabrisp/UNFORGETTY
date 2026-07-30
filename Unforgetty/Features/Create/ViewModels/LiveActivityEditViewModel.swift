import SwiftUI
import Combine

@MainActor
final class LiveActivityEditViewModel: DraftEditingViewModel, Identifiable {
    @Published private(set) var activity: ScheduledActivity
    @Published var tagName = ""
    @Published var showingEditSheet = false

    var id: UUID { activity.id }

    var draft: LiveActivityDraft {
        get { activity.draft }
        set { activity.draft = newValue }
    }

    init(activity: ScheduledActivity) {
        self.activity = activity
    }

    func saveChanges(store: ActivityStore) async {
        store.update(activity)
        if let liveActivityID = activity.liveActivityID {
            await LiveActivityController.refresh(id: liveActivityID)
        }
    }

    func endActivity(store: ActivityStore) async {
        if let liveActivityID = activity.liveActivityID {
            await LiveActivityController.end(id: liveActivityID)
        }
        store.complete(activity)
    }
}

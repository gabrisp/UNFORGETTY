import Foundation
import Combine

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var activities: [ScheduledActivity] = CoreDataActivityStore.load() {
        didSet {
            CoreDataActivityStore.save(activities)
            SharedActivityStore.save(activities)
        }
    }
    @Published var isPremium = false
    @Published var purchaseError: String?

    init() {
        SharedActivityStore.save(activities)
    }

    var tags: [Tag] { Array(Set(activities.flatMap(\.draft.tags))).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    var liveActivityCards: [ScheduledActivity] {
        activities
            .filter { $0.surface == .liveActivity }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var liveActivityDrafts: [ScheduledActivity] {
        liveActivityCards.filter { $0.status == .draft }
    }

    func save(_ activity: ScheduledActivity) { activities.removeAll { $0.id == activity.id }; activities.append(activity); activities.sort { $0.startDate > $1.startDate } }
    func update(_ activity: ScheduledActivity) { save(activity) }
    func ensureInitialLiveActivityDraft() {
        guard liveActivityCards.isEmpty else { return }
        save(ScheduledActivity(draft: LiveActivityDraft(), surface: .liveActivity, startDate: .now, status: .draft))
    }

    func createLiveActivityDraft() -> ScheduledActivity {
        let activity = ScheduledActivity(draft: LiveActivityDraft(), surface: .liveActivity, startDate: .now, status: .draft)
        save(activity)
        return activity
    }

    func discardEmptyLiveActivityDraft(_ activity: ScheduledActivity) {
        guard activity.surface == .liveActivity, activity.status == .draft, !activity.draft.isValid else { return }
        activities.removeAll { $0.id == activity.id }
    }

    func syncFromSharedStore() {
        let mirroredActivities = SharedActivityStore.load()
        guard !mirroredActivities.isEmpty, mirroredActivities != activities else { return }
        activities = mirroredActivities.sorted { $0.startDate > $1.startDate }
    }

    func delete(_ activity: ScheduledActivity) {
        guard !activity.draft.isStrict else { return }
        if activity.surface == .notification {
            LocalNotificationScheduler.cancel(activity)
        }
        activities.removeAll { $0.id == activity.id }
    }

    func deleteLiveActivityCard(id: UUID) {
        activities.removeAll { $0.id == id }
    }

    func complete(_ activity: ScheduledActivity) {
        guard let i = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        if activities[i].surface == .notification {
            LocalNotificationScheduler.cancel(activities[i])
        }
        activities[i].status = .completed
        activities[i].liveActivityID = nil
    }
    func toggleTask(_ itemID: UUID, activityID: UUID) {
        guard let index = activities.firstIndex(where: { $0.id == activityID }), let itemIndex = activities[index].draft.checklistItems.firstIndex(where: { $0.id == itemID }) else { return }
        activities[index].draft.checklistItems[itemIndex].isCompleted.toggle()
    }
    func makeTag(named name: String) -> Tag { Tag(name: name.trimmingCharacters(in: .whitespacesAndNewlines)) }
}

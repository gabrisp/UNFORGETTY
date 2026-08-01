import Foundation
import Combine
import EventKit
import ActivityKit
import CoreLocation

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
    private var liveActivityUpdatesTask: Task<Void, Never>?
    private var liveActivityStateTasks: [String: Task<Void, Never>] = [:]

    init() {
        // Live Activity intents update the App Group while the app is closed.
        // Restore that mirror before writing the older Core Data snapshot back.
        let mirroredActivities = SharedActivityStore.load()
        if !mirroredActivities.isEmpty {
            activities = mirroredActivities.sorted { $0.startDate > $1.startDate }
            CoreDataActivityStore.save(activities)
        } else {
            SharedActivityStore.save(activities)
        }
        LocationActivityMonitor.shared.attach(store: self)
        LocationActivityMonitor.shared.restore(activities)
        observeLiveActivities()
    }

    deinit {
        liveActivityUpdatesTask?.cancel()
        liveActivityStateTasks.values.forEach { $0.cancel() }
    }

    private func observeLiveActivities() {
        for activity in Activity<UnforgettyActivityAttributes>.activities {
            reconcileLiveActivityID(for: activity)
            observeLiveActivityState(for: activity)
        }

        liveActivityUpdatesTask = Task { [weak self] in
            for await activity in Activity<UnforgettyActivityAttributes>.activityUpdates {
                guard !Task.isCancelled else { return }
                self?.reconcileLiveActivityID(for: activity)
                self?.observeLiveActivityState(for: activity)
            }
        }
    }

    /// A scheduled activity fired remotely via push-to-start never goes through `start()`, so the
    /// app never learns the resulting `Activity.id` any other way — without this, `liveActivityID`
    /// stays nil forever and neither the "Live" pill nor ending it locally can work. Friend pings
    /// (whose `notificationID` never matches a locally-created activity) are a no-op here.
    private func reconcileLiveActivityID(for activity: Activity<UnforgettyActivityAttributes>) {
        let notificationID = activity.attributes.notificationID
        guard let index = activities.firstIndex(where: { $0.notificationID == notificationID }) else { return }
        guard activities[index].liveActivityID != activity.id else { return }
        activities[index].liveActivityID = activity.id
        if activities[index].status != .active {
            activities[index].status = .active
        }
    }

    private func observeLiveActivityState(for activity: Activity<UnforgettyActivityAttributes>) {
        guard liveActivityStateTasks[activity.id] == nil else { return }

        liveActivityStateTasks[activity.id] = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard state == .ended || state == .dismissed else { continue }

                self?.markLiveActivityAsEnded(notificationID: activity.attributes.notificationID)
                return
            }
        }
    }

    private func markLiveActivityAsEnded(notificationID: String) {
        guard let index = activities.firstIndex(where: { $0.notificationID == notificationID }) else { return }
        activities[index].liveActivityID = nil
        if activities[index].status == .active {
            activities[index].status = .completed
        }
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
        guard canDelete(activity) else { return }
        LocationActivityMonitor.shared.unregister(activity)
        if activity.surface == .notification {
            LocalNotificationScheduler.cancel(activity)
        }
        activities.removeAll { $0.id == activity.id }
        SharedImageStore.deleteAll(notificationID: activity.notificationID)
    }

    func deleteLiveActivityCard(id: UUID) {
        guard let activity = activities.first(where: { $0.id == id }), canDelete(activity) else { return }
        LocationActivityMonitor.shared.unregister(activity)
        activities.removeAll { $0.id == id }
        SharedImageStore.deleteAll(notificationID: activity.notificationID)
    }

    private func canDelete(_ activity: ScheduledActivity) -> Bool {
        guard activity.draft.isStrict, activity.draft.kind == .check(.todoList) else { return true }
        return !activity.draft.checklistItems.isEmpty && activity.draft.checklistItems.allSatisfy(\.isCompleted)
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
        if let reminderID = activities[index].draft.checklistItems[itemIndex].reminderID {
            let isCompleted = activities[index].draft.checklistItems[itemIndex].isCompleted
            Task { await RemindersSyncService.setCompleted(isCompleted, reminderID: reminderID) }
        }
    }
    func makeTag(named name: String) -> Tag { Tag(name: name.trimmingCharacters(in: .whitespacesAndNewlines)) }
}

@MainActor
final class LocationActivityMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = LocationActivityMonitor()

    private let locationManager = CLLocationManager()
    private weak var store: ActivityStore?
    private var activitiesByRegionID: [String: ScheduledActivity] = [:]

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func attach(store: ActivityStore) {
        self.store = store
    }

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func restore(_ activities: [ScheduledActivity]) {
        for activity in activities where activity.status == .scheduled && activity.locationTriggerEnabled {
            register(activity)
        }
    }

    func register(_ activity: ScheduledActivity) {
        guard
            let latitude = activity.locationLatitude,
            let longitude = activity.locationLongitude,
            CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
        else { return }

        let regionID = activity.notificationID
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: min(activity.locationRadius, locationManager.maximumRegionMonitoringDistance),
            identifier: regionID
        )
        region.notifyOnEntry = true
        activitiesByRegionID[regionID] = activity
        locationManager.startMonitoring(for: region)
    }

    func unregister(_ activity: ScheduledActivity) {
        activitiesByRegionID.removeValue(forKey: activity.notificationID)
        for region in locationManager.monitoredRegions where region.identifier == activity.notificationID {
            locationManager.stopMonitoring(for: region)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let activity = activitiesByRegionID[region.identifier], activity.status == .scheduled else { return }

        Task {
            do {
                let liveActivityID = try await LiveActivityController.start(activity)
                var activeActivity = activity
                activeActivity.status = .active
                activeActivity.liveActivityID = liveActivityID
                store?.update(activeActivity)
                unregister(activity)
            } catch {
                // Keep it scheduled so the next entry can retry.
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        for activity in activitiesByRegionID.values {
            register(activity)
        }
    }
}

@MainActor
enum RemindersSyncService {
    private static let eventStore = EKEventStore()

    static func requestAccess() async -> Bool {
        (try? await eventStore.requestFullAccessToReminders()) == true
    }

    static func reminderLists() -> [EKCalendar] {
        eventStore.calendars(for: .reminder).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    static func incompleteReminders(in calendarID: String?) async -> [EKReminder] {
        let calendar = calendarID.flatMap { id in
            eventStore.calendar(withIdentifier: id)
        }
        let predicate = eventStore.predicateForReminders(in: calendar.map { [$0] })
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).filter { !$0.isCompleted })
            }
        }
    }

    static func setCompleted(_ isCompleted: Bool, reminderID: String) {
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else { return }
        reminder.isCompleted = isCompleted
        try? eventStore.save(reminder, commit: true)
    }
}

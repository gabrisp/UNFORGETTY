import SwiftUI
import Combine

@MainActor
final class CreateActivityViewModel: DraftEditingViewModel {
    @Published var draft = LiveActivityDraft()
    @Published var isScheduling = false
    @Published var selectedWeekdays: Set<Weekday> = []
    @Published var scheduleTime = Date.now
    @Published var tagName = ""
    @Published private(set) var errorMessage: String?

    func clearError() { errorMessage = nil }

    func toggleScheduling(_ isOn: Bool) {
        withAnimation(.snappy) { isScheduling = isOn }
    }

    func toggleWeekday(_ day: Weekday) {
        withAnimation(.snappy) {
            if selectedWeekdays.contains(day) { selectedWeekdays.remove(day) } else { selectedWeekdays.insert(day) }
        }
    }

    func send(store: ActivityStore, surface: ActivitySurface) async {
        switch surface {
        case .liveActivity:
            if isScheduling {
                await scheduleLiveActivity(store: store)
            } else {
                await launchNow(store: store)
            }
        case .notification:
            await sendNotification(store: store)
        case .widget:
            await saveWidget(store: store)
        }
    }

    private func launchNow(store: ActivityStore) async {
        var activity = ScheduledActivity(draft: draft, surface: .liveActivity, startDate: .now, status: .active)
        store.save(activity)

        do {
            activity.liveActivityID = try await LiveActivityController.start(activity)
            store.update(activity)
            EventTracker.track("local_activity_started")
            reset()
        } catch {
            store.delete(activity)
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleLiveActivity(store: ActivityStore) async {
        let activity = ScheduledActivity(draft: draft, surface: .liveActivity, startDate: nextOccurrence(), recurrence: selectedWeekdays, status: .scheduled)
        store.save(activity)
        do {
            try await PrivateScheduler.register(activity)
            EventTracker.track("activity_scheduled")
            reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendNotification(store: ActivityStore) async {
        let activity = ScheduledActivity(
            draft: draft,
            surface: .notification,
            startDate: isScheduling ? nextOccurrence() : .now,
            recurrence: isScheduling ? selectedWeekdays : [],
            status: isScheduling ? .scheduled : .active
        )

        do {
            try await LocalNotificationScheduler.schedule(activity)
            store.save(activity)
            EventTracker.track(isScheduling ? "notification_scheduled" : "notification_sent")
            reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveWidget(store: ActivityStore) async {
        let activity = ScheduledActivity(draft: draft, surface: .widget, startDate: .now, status: .active)
        store.save(activity)
        EventTracker.track("widget_saved")
        reset()
    }

    private func nextOccurrence() -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: scheduleTime)
        for offset in 0..<8 {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
            let calendarWeekday = calendar.component(.weekday, from: candidateDay)
            guard let weekday = Weekday(calendarWeekday: calendarWeekday), selectedWeekdays.contains(weekday) else { continue }
            var combined = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            combined.hour = time.hour
            combined.minute = time.minute
            if let date = calendar.date(from: combined), date > .now { return date }
        }
        return scheduleTime
    }

    func reset() {
        withAnimation(.snappy) {
            draft = LiveActivityDraft()
            isScheduling = false
            selectedWeekdays = []
        }
    }
}

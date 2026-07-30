import SwiftUI
import Combine

@MainActor
final class CreateActivityV2EditViewModel: DraftEditingViewModel, ObservableObject {
    @Published var activity: ScheduledActivity
    @Published var isScheduling: Bool
    @Published var selectedWeekdays: Set<Weekday>
    @Published var scheduleTime: Date
    @Published var tagName = ""
    @Published private(set) var errorMessage: String?

    var draft: LiveActivityDraft {
        get { activity.draft }
        set {
            activity.draft = newValue
        }
    }

    init(activity: ScheduledActivity = ScheduledActivity(draft: LiveActivityDraft(), surface: .liveActivity, startDate: .now, status: .draft)) {
        self.activity = activity
        self.isScheduling = !activity.recurrence.isEmpty || activity.startDate > .now.addingTimeInterval(1)
        self.selectedWeekdays = activity.recurrence
        self.scheduleTime = activity.startDate
    }

    func load(_ activity: ScheduledActivity) {
        self.activity = activity
        self.isScheduling = !activity.recurrence.isEmpty || activity.startDate > .now.addingTimeInterval(1)
        self.selectedWeekdays = activity.recurrence
        self.scheduleTime = activity.startDate
        self.tagName = ""
        self.errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func setKind(_ kind: ActivityKind) {
        withAnimation(.snappy) {
            draft.kind = kind
            if draft.checklistItems.isEmpty {
                draft.checklistItems = [ChecklistItem(text: "")]
            }
        }
    }

    func toggleScheduling(_ isOn: Bool) {
        withAnimation(.snappy) {
            isScheduling = isOn
            activity.startDate = scheduleDate
            activity.recurrence = isOn ? selectedWeekdays : []
        }
    }

    func toggleWeekday(_ day: Weekday) {
        withAnimation(.snappy) {
            if selectedWeekdays.contains(day) {
                selectedWeekdays.remove(day)
            } else {
                selectedWeekdays.insert(day)
            }
            activity.recurrence = isScheduling ? selectedWeekdays : []
            activity.startDate = scheduleDate
        }
    }

    func saveDraft(store: ActivityStore) {
        let currentStatus = activity.status
        activity.surface = .liveActivity
        activity.status = currentStatus
        if isScheduling {
            activity.startDate = scheduleDate
            activity.recurrence = selectedWeekdays
        } else {
            activity.recurrence = []
        }
        store.update(activity)
        if let liveActivityID = activity.liveActivityID {
            Task { await LiveActivityController.refresh(id: liveActivityID) }
        }
    }

    func send(store: ActivityStore) async -> Bool {
        let previousActivity = activity
        let previousLiveActivityID = activity.liveActivityID

        activity.surface = .liveActivity
        activity.startDate = isScheduling ? scheduleDate : .now
        activity.recurrence = isScheduling ? selectedWeekdays : []

        if isScheduling {
            activity.status = .scheduled
            activity.liveActivityID = nil
            store.update(activity)

            do {
                try await PrivateScheduler.register(activity)
                if let previousLiveActivityID {
                    await LiveActivityController.end(id: previousLiveActivityID)
                }
                EventTracker.track("activity_scheduled")
                return true
            } catch {
                activity = previousActivity
                store.update(activity)
                errorMessage = error.localizedDescription
                return false
            }
        }

        activity.status = .active
        activity.liveActivityID = nil
        store.update(activity)

        do {
            activity.liveActivityID = try await LiveActivityController.start(activity)
            store.update(activity)
            if let previousLiveActivityID {
                await LiveActivityController.end(id: previousLiveActivityID)
            }
            EventTracker.track("local_activity_started")
            return true
        } catch {
            activity = previousActivity
            store.update(activity)
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var scheduleDate: Date {
        guard isScheduling else { return .now }
        return nextOccurrence()
    }

    private func nextOccurrence() -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: scheduleTime)

        guard !selectedWeekdays.isEmpty else {
            return scheduleTime
        }

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
}

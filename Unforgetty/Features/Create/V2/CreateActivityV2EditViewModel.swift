import SwiftUI
import Combine
import EventKit

@MainActor
final class CreateActivityV2EditViewModel: DraftEditingViewModel, ObservableObject {
    @Published var activity: ScheduledActivity
    @Published var isScheduling: Bool
    @Published var selectedWeekdays: Set<Weekday>
    @Published var scheduleTime: Date
    @Published var scheduleEndDate: Date?
    @Published private(set) var reminderLists: [EKCalendar] = []
    @Published var tagName = ""
    @Published private(set) var errorMessage: String?

    // Sending to a friend is a one-off ping (SocialRepository.sendToFriend), not part of this
    // activity's own persisted schedule — it's consumed by `send()` and not saved to `activity`.
    // Only available for .note/.music: actions are device-local shortcuts, checklists don't sync
    // cross-device, and images can't fit in the ~4KB APNs content-state payload.
    static let maxFriendRecipients = 5
    @Published var sendToFriendUsernames: [String] = []
    @Published var friendMessage = ""
    @Published private(set) var myUsername: String?
    @Published private(set) var friends: [SocialRepository.Friend] = []

    static let autoEndDurationOptions: [(title: String, seconds: TimeInterval?)] = [
        ("1 hora", 3600),
        ("3 horas", 3600 * 3),
        ("6 horas", 3600 * 6),
        ("8 horas (máximo)", 3600 * 8),
        ("Sin límite", nil)
    ]

    static func autoEndDurationTitle(for seconds: TimeInterval?) -> String {
        autoEndDurationOptions.first { $0.seconds == seconds }?.title ?? "Sin límite"
    }

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
        self.scheduleEndDate = activity.endDate
    }

    func load(_ activity: ScheduledActivity) {
        self.activity = activity
        self.isScheduling = !activity.recurrence.isEmpty || activity.startDate > .now.addingTimeInterval(1)
        self.selectedWeekdays = activity.recurrence
        self.scheduleTime = activity.startDate
        self.scheduleEndDate = activity.endDate
        self.tagName = ""
        self.errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func setKind(_ kind: ActivityKind) {
        withAnimation(.snappy) {
            draft.kind = kind
            if kind != .image, draft.style.backgroundMode == .image {
                draft.style.backgroundMode = .plain
            }
            if kind == .image {
                draft.style.backgroundMode = .image
            }
            if kind.isCheck, draft.blurContentMode == .tapToToggle {
                draft.blurContentMode = .never
            }
            if kind == .check(.todoList), draft.checklistItems.isEmpty {
                draft.checklistItems = [ChecklistItem(text: "")]
            }
            if kind == .check(.buttons) {
                ensureDefaultLiveActions()
            }
        }
    }

    func loadFriends() async {
        myUsername = try? await SocialRepository.shared.myUsername()
        friends = (try? await SocialRepository.shared.listFriends()) ?? []
    }

    @discardableResult
    func claimUsername(_ username: String) async -> Bool {
        do {
            myUsername = try await SocialRepository.shared.claimUsername(username)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeFriend(_ friend: SocialRepository.Friend) async {
        do {
            try await SocialRepository.shared.removeFriend(userID: friend.userID)
            friends.removeAll { $0.id == friend.id }
            sendToFriendUsernames.removeAll { $0 == friend.username }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectTrack(_ track: SpotifyRepository.SpotifyTrack) async {
        draft.musicTitle = track.name
        draft.musicArtist = track.artist
        draft.musicAlbum = track.album
        draft.musicSpotifyTrackID = track.id
        draft.musicSpotifyURL = track.spotifyURL
        draft.musicAlbumArtURL = track.albumArtURL
        draft.musicAlbumArtData = nil
        if let albumArtURL = track.albumArtURL, let url = URL(string: albumArtURL),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            draft.musicAlbumArtData = ImagePreparation.preparedBackgroundImageData(from: data)

            if !draft.style.backgroundIsCustomized, let (start, end) = ImagePreparation.gradientHexPair(from: data) {
                draft.style.backgroundMode = .gradient
                draft.style.gradientStartHex = start
                draft.style.gradientEndHex = end
            }
        }
    }

    func toggleScheduling(_ isOn: Bool) {
        withAnimation(.snappy) {
            isScheduling = isOn
            activity.startDate = scheduleDate
            activity.recurrence = isOn ? selectedWeekdays : []
            activity.endDate = isOn && !selectedWeekdays.isEmpty ? scheduleEndDate : nil
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
            activity.endDate = isScheduling && !selectedWeekdays.isEmpty ? scheduleEndDate : nil
        }
    }

    func setScheduleEndDate(_ date: Date?) {
        withAnimation(.snappy) {
            scheduleEndDate = date
            activity.endDate = isScheduling && !selectedWeekdays.isEmpty ? scheduleEndDate : nil
        }
    }

    func setRemindersSync(_ enabled: Bool, store: ActivityStore) {
        draft.syncWithReminders = enabled
        saveDraft(store: store)
        guard enabled, draft.kind == .check(.todoList) else { return }

        Task {
            guard await RemindersSyncService.requestAccess() else {
                draft.syncWithReminders = false
                saveDraft(store: store)
                return
            }

            reminderLists = RemindersSyncService.reminderLists()
            if draft.reminderListID == nil {
                draft.reminderListID = reminderLists.first?.calendarIdentifier
            }
            await syncReminders(store: store)
        }
    }

    func setReminderList(_ listID: String?, store: ActivityStore) {
        draft.reminderListID = listID
        saveDraft(store: store)
        guard draft.syncWithReminders else { return }
        Task { await syncReminders(store: store) }
    }

    private func syncReminders(store: ActivityStore) async {
        let reminders = await RemindersSyncService.incompleteReminders(in: draft.reminderListID)
        await MainActor.run {
            draft.checklistItems = Array(reminders.prefix(6)).map {
                ChecklistItem(
                    text: $0.title,
                    isCompleted: $0.isCompleted,
                    reminderID: $0.calendarItemIdentifier
                )
            }
            if draft.checklistItems.isEmpty {
                draft.checklistItems = [ChecklistItem(text: "")]
            }
            saveDraft(store: store)
        }
    }

    func saveDraft(store: ActivityStore) {
        let currentStatus = activity.status
        activity.surface = .liveActivity
        activity.status = currentStatus
        if isScheduling {
            activity.startDate = scheduleDate
            activity.recurrence = selectedWeekdays
            activity.endDate = !selectedWeekdays.isEmpty ? scheduleEndDate : nil
        } else {
            activity.recurrence = []
            activity.endDate = nil
        }
        store.update(activity)
        if let liveActivityID = activity.liveActivityID {
            Task { await LiveActivityController.refresh(id: liveActivityID) }
        }
    }

    func send(store: ActivityStore) async -> Bool {
        if !sendToFriendUsernames.isEmpty {
            guard draft.kind == .note || draft.kind == .music else {
                errorMessage = "Solo se pueden enviar notas y música a amigos."
                return false
            }
            guard let myUsername else {
                errorMessage = "Necesitas un username antes de poder enviar a un amigo."
                return false
            }
            let trimmedMessage = friendMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedMessage.isEmpty else {
                errorMessage = "Escribe un mensaje para tu amigo."
                return false
            }
            let snapshot = draft.friendActivitySnapshot
            do {
                for toUsername in sendToFriendUsernames {
                    try await SocialRepository.shared.sendToFriend(fromUsername: myUsername, toUsername: toUsername, message: trimmedMessage, snapshot: snapshot)
                }
                friendMessage = ""
                EventTracker.track("friend_ping_sent")
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }

        let previousActivity = activity
        let previousLiveActivityID = activity.liveActivityID

        activity.surface = .liveActivity
        activity.startDate = isScheduling ? scheduleDate : .now
        activity.recurrence = isScheduling ? selectedWeekdays : []
        activity.endDate = isScheduling && !selectedWeekdays.isEmpty ? scheduleEndDate : nil

        if activity.locationTriggerEnabled {
            activity.status = .scheduled
            activity.liveActivityID = nil
            store.update(activity)
            LocationActivityMonitor.shared.register(activity)
            EventTracker.track("activity_location_scheduled")
            return true
        }

        if isScheduling {
            activity.status = .scheduled
            activity.liveActivityID = nil
            store.update(activity)

            do {
                guard let pushToStartToken = await LiveActivityController.ensurePushToStartToken() else {
                    throw PrivateSchedulerError.pushToStartTokenUnavailable
                }
                // The server's cron only understands weekly recurrence, so a "just this one day"
                // schedule (no weekdays picked) is sent as a single synthetic weekday paired with
                // an endDate right after it — it fires once, then the server marks it ended.
                // The locally-stored `activity` keeps the user's real (possibly empty) selection.
                var payloadActivity = activity
                payloadActivity.recurrence = effectiveRecurrence
                payloadActivity.endDate = effectiveEndDate
                try await PrivateScheduler.register(payloadActivity, token: pushToStartToken)
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

        // A Live Activity is already on screen for this draft: just push the new content to it
        // instead of ending it and starting a fresh one, which would flicker and burn a start slot.
        if let previousLiveActivityID {
            activity.liveActivityID = previousLiveActivityID
            store.update(activity)
            await LiveActivityController.refresh(id: previousLiveActivityID)
            EventTracker.track("local_activity_updated")
            return true
        }

        activity.liveActivityID = nil
        store.update(activity)

        do {
            activity.liveActivityID = try await LiveActivityController.start(activity)
            store.update(activity)
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

    /// The earliest occurrence on/after the user-picked `scheduleTime` (a real future date+time,
    /// not just a time-of-day) whose weekday is selected. Empty selection means "just this once,
    /// on that exact date".
    private func nextOccurrence() -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: scheduleTime)

        guard !selectedWeekdays.isEmpty else {
            return scheduleTime
        }

        for offset in 0..<8 {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: scheduleTime) else { continue }
            let calendarWeekday = calendar.component(.weekday, from: candidateDay)
            guard let weekday = Weekday(calendarWeekday: calendarWeekday), selectedWeekdays.contains(weekday) else { continue }
            var combined = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            combined.hour = time.hour
            combined.minute = time.minute
            if let date = calendar.date(from: combined) { return date }
        }

        return scheduleTime
    }

    /// What actually gets sent to the scheduler: the server's cron only understands weekly
    /// recurrence, so a one-off date is represented as a single matching weekday.
    private var effectiveRecurrence: Set<Weekday> {
        guard selectedWeekdays.isEmpty else { return selectedWeekdays }
        let calendarWeekday = Calendar.current.component(.weekday, from: scheduleDate)
        return Weekday(calendarWeekday: calendarWeekday).map { [$0] } ?? []
    }

    /// Paired with `effectiveRecurrence`: for a one-off date this caps it to a single firing —
    /// the server marks the job "ended" once past this date instead of repeating next week.
    private var effectiveEndDate: Date? {
        guard selectedWeekdays.isEmpty else { return scheduleEndDate }
        return Calendar.current.date(byAdding: .day, value: 1, to: scheduleDate)
    }
}

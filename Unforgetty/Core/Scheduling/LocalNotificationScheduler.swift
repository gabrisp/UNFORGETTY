import Foundation
import UserNotifications

enum LocalNotificationScheduler {
    static func schedule(_ activity: ScheduledActivity) async throws {
        let center = UNUserNotificationCenter.current()
        try await ensureAuthorization(center: center)
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: activity))

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: activity)
        content.body = notificationBody(for: activity)
        content.sound = .default
        content.userInfo = [
            "notificationID": activity.notificationID,
            "activityID": activity.id.uuidString
        ]

        if activity.recurrence.isEmpty {
            let trigger = oneShotTrigger(for: activity.startDate)
            let request = UNNotificationRequest(identifier: activity.notificationID, content: content, trigger: trigger)
            try await center.add(request)
            return
        }

        for weekday in activity.recurrence {
            var components = Calendar.current.dateComponents([.hour, .minute], from: activity.startDate)
            components.weekday = calendarWeekday(for: weekday)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "\(activity.notificationID).\(weekday.rawValue)", content: content, trigger: trigger)
            try await center.add(request)
        }
    }

    static func cancel(_ activity: ScheduledActivity) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers(for: activity))
    }

    private static func ensureAuthorization(center: UNUserNotificationCenter) async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted { return }
        case .denied:
            break
        @unknown default:
            break
        }

        throw NSError(
            domain: "Unforgetty.LocalNotificationScheduler",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Activa las notificaciones para poder programarla."]
        )
    }

    private static func oneShotTrigger(for date: Date) -> UNNotificationTrigger {
        let interval = max(1, date.timeIntervalSinceNow)
        return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    }

    private static func identifiers(for activity: ScheduledActivity) -> [String] {
        if activity.recurrence.isEmpty {
            return [activity.notificationID]
        }
        return activity.recurrence.map { "\(activity.notificationID).\($0.rawValue)" }
    }

    private static func notificationTitle(for activity: ScheduledActivity) -> String {
        let trimmedTitle = activity.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Unforgetty" : trimmedTitle
    }

    private static func notificationBody(for activity: ScheduledActivity) -> String {
        if activity.draft.kind == .note {
            let trimmedBody = activity.draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedBody.isEmpty ? "Tienes una nota pendiente." : trimmedBody
        }

        return activity.draft.checklistItems
            .map(\.text)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? "Tienes una tarea pendiente."
    }

    private static func calendarWeekday(for weekday: Weekday) -> Int {
        switch weekday {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }
}

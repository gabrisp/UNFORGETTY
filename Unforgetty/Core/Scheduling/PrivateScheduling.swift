import Foundation
import UIKit

/// The only payload allowed to leave the device. Appwrite receives no user content.
nonisolated struct PrivateSchedulePayload: Codable {
    let notificationID: String
    let deviceID: String
    let startDate: Date
    let endDate: Date?
    let recurrence: Set<Weekday>
    let pushToStartToken: String?
}

enum PrivateScheduler {
    static func register(_ activity: ScheduledActivity, token: String? = nil) async throws {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let payload = PrivateSchedulePayload(notificationID: activity.notificationID, deviceID: deviceID, startDate: activity.startDate, endDate: activity.endDate, recurrence: activity.recurrence, pushToStartToken: token)
        try await AppwriteFunctionsRepository.shared.executeScheduler(payload)
    }
}

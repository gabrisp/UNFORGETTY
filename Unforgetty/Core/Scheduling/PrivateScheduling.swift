import Foundation

/// The only payload allowed to leave the device. Appwrite receives no user content.
nonisolated struct PrivateSchedulePayload: Codable {
    let notificationID: String
    // Named `deviceID` to match the existing Appwrite collection attribute, but it carries the
    // Appwrite messaging target ID (see AppwritePushIdentity.registerPushTarget), not a local device identifier.
    let deviceID: String
    let timeZoneIdentifier: String
    let startDate: Date
    let endDate: Date?
    let recurrence: Set<Weekday>
    let pushToStartToken: String?
    /// How long each fired Live Activity instance should stay visible, in seconds. Distinct from
    /// `endDate`, which caps how long the weekly recurrence itself keeps repeating.
    let autoEndDuration: TimeInterval?
}

enum PrivateScheduler {
    static func register(_ activity: ScheduledActivity, token: String? = nil) async throws {
        guard activity.status == .scheduled, !activity.recurrence.isEmpty else {
            return
        }
        guard let targetID = await AppwritePushIdentity.shared.ensurePushTarget() else {
            throw PrivateSchedulerError.pushTargetUnavailable
        }
        let payload = PrivateSchedulePayload(notificationID: activity.notificationID, deviceID: targetID, timeZoneIdentifier: TimeZone.current.identifier, startDate: activity.startDate, endDate: activity.endDate, recurrence: activity.recurrence, pushToStartToken: token, autoEndDuration: activity.autoEndDuration.map { min($0, LiveActivityController.maxAutoEndDuration) })
        try await AppwriteFunctionsRepository.shared.executeScheduler(payload)
    }
}

enum PrivateSchedulerError: LocalizedError {
    case pushToStartTokenUnavailable
    case pushTargetUnavailable

    var errorDescription: String? {
        switch self {
        case .pushToStartTokenUnavailable: "Activa las notificaciones para poder programar."
        case .pushTargetUnavailable: "Activa las notificaciones para poder programar."
        }
    }
}

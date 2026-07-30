import Foundation
import Combine

@MainActor
final class CreatedActivitiesViewModel: ObservableObject {
    @Published var showingPaywall = false

    func visibleActivities(from activities: [ScheduledActivity]) -> [ScheduledActivity] {
        activities.filter { $0.status != .completed }
    }
}

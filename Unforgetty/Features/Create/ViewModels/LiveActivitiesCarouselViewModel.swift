import Foundation
import Combine

@MainActor
final class LiveActivitiesCarouselViewModel: ObservableObject {
    @Published private(set) var pages: [LiveActivityEditViewModel] = []
    private var cancellable: AnyCancellable?

    func bind(to store: ActivityStore) {
        sync(with: store.activities)
        cancellable = store.$activities.sink { [weak self] activities in
            self?.sync(with: activities)
        }
    }

    private func sync(with activities: [ScheduledActivity]) {
        let liveActivities = activities.filter { $0.status == .active }
        let liveIDs = Set(liveActivities.map(\.id))
        pages.removeAll { !liveIDs.contains($0.id) }
        let existingIDs = Set(pages.map(\.id))
        for activity in liveActivities where !existingIDs.contains(activity.id) {
            pages.append(LiveActivityEditViewModel(activity: activity))
        }
    }
}

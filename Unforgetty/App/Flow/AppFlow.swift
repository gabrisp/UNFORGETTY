import Foundation
import Combine

@MainActor
final class AppFlowViewModel: ObservableObject {
    enum Destination { case splash, onboarding, root }

    @Published private(set) var destination: Destination = .splash
    @Published private(set) var ckUserID = ""

    func bootstrap(store: ActivityStore) async {
        ckUserID = CKUserIdentity.resolve()
        await store.preparePurchases(appUserID: ckUserID)
        destination = UserDefaults.standard.bool(forKey: "hasFinishedOnboarding") ? .root : .onboarding
    }

    func showRoot() { destination = .root }
}

import Foundation
import Combine

@MainActor
final class AppFlowViewModel: ObservableObject {
    enum Destination { case splash, onboarding, root }

    @Published private(set) var destination: Destination = .splash
    @Published private(set) var ckUserID = ""
    @Published var isShowingPaywall = false
    @Published var presentedReceivedFriendPingID: String?

    func bootstrap(store: ActivityStore) async {
        NSLog("Unforgetty: bootstrap starting")
        do {
            ckUserID = try await AppwritePushIdentity.shared.ensureAnonymousUser()
            NSLog("Unforgetty: bootstrap got ckUserID=%@", ckUserID)
        } catch {
            NSLog("Unforgetty: anonymous user registration failed: %@", error.localizedDescription)
            ckUserID = CKUserIdentity.resolve()
        }
        await store.preparePurchases(appUserID: ckUserID)
        destination = UserDefaults.standard.bool(forKey: "hasFinishedOnboarding") ? .root : .onboarding
        NSLog("Unforgetty: bootstrap finished, destination=%@", String(describing: destination))
    }

    func showRoot() { destination = .root }
    func showPaywall() { isShowingPaywall = true }

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "unforgetty", url.host == "friend-ping" else { return }
        let notificationID = url.pathComponents.dropFirst().first ?? url.lastPathComponent
        guard !notificationID.isEmpty else { return }
        presentedReceivedFriendPingID = notificationID
    }
}

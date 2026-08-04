import Foundation
import Combine

enum RootTab: Hashable {
    case main
    case receivedFromFriends
}

@MainActor
final class AppFlowViewModel: ObservableObject {
    enum Destination { case splash, onboarding, root }

    @Published private(set) var destination: Destination = .splash
    @Published private(set) var ckUserID = ""
    @Published var isShowingPaywall = false
    @Published var presentedReceivedFriendPingID: String?
    @Published var selectedTab: RootTab = .main
    /// Set by "Reeditar" on a received friend ping (a different tab/screen from the editor) once
    /// it has saved the new draft into `ActivityStore` — the main tab observes this to select and
    /// open that draft, then clears it. Neither tab reaches into the other's view state directly.
    @Published var pendingSelectedActivityID: UUID?

    func openActivityForEditing(_ id: UUID) {
        selectedTab = .main
        pendingSelectedActivityID = id
    }

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
        resyncPushToStartTokenIfNeeded()
    }

    /// Closes the same gap SocialSettingsModel's refresh()/claimUsername() close, but without
    /// requiring the user to specifically visit Settings first — this fires on every app launch.
    /// See updatePushToken's doc comment in AppwriteFunctions/social: the backend silently drops
    /// a push-to-start token if it arrives before this device's Profile document exists (e.g.
    /// before onboarding claims a username), so it has to be re-sent once we know a username is
    /// actually in place, from whatever launch first has both a cached token and a claimed
    /// username — not just from the Settings screen specifically.
    private func resyncPushToStartTokenIfNeeded() {
        guard let cachedToken = LiveActivityController.pushToStartToken() else { return }
        Task {
            guard let username = try? await SocialRepository.shared.myUsername(), username != nil else { return }
            try? await SocialRepository.shared.updatePushToken(cachedToken)
            print("Unforgetty: bootstrap re-synced cached pushToStartToken for username=\(username ?? "?")")
        }
    }

    func showRoot() { destination = .root }
    func showPaywall() { isShowingPaywall = true }
    func showOnboarding() { destination = .onboarding }

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "unforgetty", url.host == "friend-ping" else { return }
        let notificationID = url.pathComponents.dropFirst().first ?? url.lastPathComponent
        guard !notificationID.isEmpty else { return }
        presentedReceivedFriendPingID = notificationID
    }
}

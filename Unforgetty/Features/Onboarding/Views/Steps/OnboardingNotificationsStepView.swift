import SwiftUI
import UIKit
import UserNotifications

struct OnboardingNotificationsStepView: View {
    var body: some View {
        OnboardingStepLayout(
            title: "Stay in the loop",
            subtitle: "Turn on notifications so friends, family, or your partner can reach you — and so your Live Activities can be scheduled and keep running without you having to think about it.",
            textAtTop: false
        ) {
            // The mockup renders its 402x874 design as an unclipped .overlay, scaled down via
            // .scaleEffect (a render-only transform SwiftUI's layout math doesn't shrink to
            // match) — without clipping, its painted pixels can bleed past this 380pt frame and
            // paint over the text below instead of stopping at the boundary.
            OnboardingV2NotificationsiPhoneView(iPhoneTint: .yellow)
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .clipped()
        }
    }
}

enum OnboardingNotificationPermission {
    /// Same async/await + status-check shape as `LocalNotificationScheduler.ensureAuthorization`,
    /// just public and side-effect-free about failure — onboarding doesn't block advancing on a
    /// denial, it just moves on, so there's nothing to throw here.
    @discardableResult
    static func request() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}

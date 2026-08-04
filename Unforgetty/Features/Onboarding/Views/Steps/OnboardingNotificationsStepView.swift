import SwiftUI
import UIKit
import UserNotifications

struct OnboardingNotificationsStepView: View {
    var body: some View {
        VStack(spacing: 0) {
            OnboardingV2NotificationsiPhoneView(iPhoneTint: .yellow)
                .frame(maxWidth: .infinity)
                .frame(height: 380)

            VStack(spacing: 12) {
                Text("Stay in the loop")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Turn on notifications so friends, family, or your partner can reach you — and so your Live Activities can be scheduled and keep running without you having to think about it.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
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

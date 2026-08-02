//
//  UnforgettyApp.swift
//  Unforgetty
//
//  Created by Gabrisp on 29/07/2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

final class UnforgettyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NSLog("Unforgetty: requesting notification authorization")
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            NSLog("Unforgetty: notification authorization granted=%@ error=%@", String(granted), error?.localizedDescription ?? "nil")
            guard granted else { return }
            DispatchQueue.main.async {
                NSLog("Unforgetty: calling registerForRemoteNotifications")
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NSLog("Unforgetty: APNs gave us a device token, registering push target")
        Task {
            do {
                let targetID = try await AppwritePushIdentity.shared.registerPushTarget(deviceToken: deviceToken)
                NSLog("Unforgetty push target registered: %@", targetID)
            } catch {
                NSLog("Unforgetty push target registration failed: %@", error.localizedDescription)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Unforgetty: APNs registration FAILED: %@", error.localizedDescription)
    }
}

/// Live Activity buttons that need to open a different app (Spotify, Shortcuts, ...) can't do it
/// directly — see WidgetContentStore.setPendingExternalLink's doc comment — so they launch this
/// app and stash the real target URL for it to open once it actually has a full process. Checked
/// on both cold launch and every foreground re-entry, since a tap can either launch the app fresh
/// or just bring an already-running one forward.
private struct PendingExternalLinkOpener: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Color.clear
            .task {
                openPendingLinkIfNeeded()
            }
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                openPendingLinkIfNeeded()
            }
            #endif
    }

    private func openPendingLinkIfNeeded() {
        guard let url = WidgetContentStore.consumePendingExternalLink() else { return }
        openURL(url)
    }
}

@main
struct UnforgettyApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(UnforgettyAppDelegate.self) private var appDelegate
    #endif
    @StateObject private var store = ActivityStore()
    @StateObject private var flow = AppFlowViewModel()

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
                .environmentObject(store)
                .environmentObject(flow)
                .task {
                    LiveActivityController.observePushToStartToken()
                    LiveActivityController.observeFriendPingUpdateTokens()
                    await flow.bootstrap(store: store)
                }
                #if canImport(UIKit)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    store.syncFromSharedStore()
                    // Silent, best-effort: catches "enabled notifications in iOS Settings while
                    // the app was backgrounded" instead of leaving scheduling broken until the
                    // user finds the debug "Force register" button.
                    Task {
                        _ = await AppwritePushIdentity.shared.ensurePushTarget()
                        _ = await LiveActivityController.ensurePushToStartToken()
                    }
                }
                #endif
                // Mounted at the root so the paywall can be triggered from anywhere in the app
                // and covers whatever is currently on screen, regardless of where it was called from.
                // Environment objects are re-attached explicitly: fullScreenCover content isn't
                // reliably inheriting them from ancestors here, hence the crash on store/flow access.
                .fullScreenCover(isPresented: $flow.isShowingPaywall) {
                    PremiumView()
                        .environmentObject(store)
                        .environmentObject(flow)
                }
                .onOpenURL { url in
                    flow.handleOpenURL(url)
                }
                .background {
                    PendingExternalLinkOpener()
                }
                .sheet(item: Binding(
                    get: { flow.presentedReceivedFriendPingID.flatMap { WidgetContentStore.receivedFriendPing(notificationID: $0) } },
                    set: { newValue in if newValue == nil { flow.presentedReceivedFriendPingID = nil } }
                )) { ping in
                    ReceivedFriendPingSheet(ping: ping)
                }
        }
    }
}

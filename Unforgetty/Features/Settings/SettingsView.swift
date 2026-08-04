import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

/// Pushed as a navigation destination (see CreateActivityV2View's `.navigationDestination`), not
/// presented as a sheet — no NavigationStack of its own here, it relies on the caller's.
struct SettingsView: View {
    @EnvironmentObject private var flow: AppFlowViewModel
    @EnvironmentObject private var store: ActivityStore
    @State private var userID: String?
    @State private var statusMessage: String?
    @State private var isStatusError = false
    @State private var isRegistering = false
    @State private var debugPayload: String?
    // Unused while the Social section above is commented out — kept ready for when it's
    // re-enabled rather than deleted alongside it.
    @StateObject private var social = SocialSettingsModel()
    @StateObject private var spotify = SpotifySettingsModel()
    @State private var isShowingDisconnectSpotifyConfirm = false
    @State private var isRefreshing = false

    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internetservices/itunes/dev/stdeula/")!
    // PLACEHOLDER — same caveat as PremiumView's own copy of this URL: must be replaced with a
    // real hosted privacy policy before release.
    private static let privacyPolicyURL = URL(string: "https://example.com")!
    // PLACEHOLDER — 0000000000 must be replaced with Unforgetty's real numeric App Store ID once
    // the app has one (App Store Connect assigns it on first upload). This link format
    // (?action=write-review) takes the user straight to the "write a review" screen in the App
    // Store app, unlike SKStoreReviewController's in-app star-only prompt.
    private static let appStoreWriteReviewURL = URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!

    var body: some View {
        List {
            Section {
                proBanner
            }

            // Social — commented out for now, not deleted; re-enable by uncommenting this
            // section (SocialSettingsModel/SocialDetailView are unchanged and ready).
            // Section {
            //     NavigationLink {
            //         SocialDetailView(model: social)
            //     } label: {
            //         HStack(spacing: 12) {
            //             Image(systemName: "person.2.fill")
            //                 .font(.title3)
            //                 .foregroundStyle(.yellow)
            //
            //             VStack(alignment: .leading, spacing: 2) {
            //                 Text("Social")
            //                     .font(.headline)
            //                 Text(social.username.map { "@\($0)" } ?? "Sin username")
            //                     .font(.caption)
            //                     .foregroundStyle(.secondary)
            //             }
            //
            //             Spacer()
            //
            //             if !social.pendingRequests.isEmpty {
            //                 Text("\(social.pendingRequests.count)")
            //                     .font(.caption2.weight(.bold))
            //                     .foregroundStyle(.white)
            //                     .frame(minWidth: 20, minHeight: 20)
            //                     .background(Circle().fill(.red))
            //             }
            //         }
            //         .padding(.vertical, 4)
            //     }
            // }

            Section("Music Accounts") {
                spotifyRow

                if let statusMessage = spotify.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(spotify.isStatusError ? .red : .secondary)
                }
            }
            .textCase(nil)

            Section("Application") {
                LegalDocumentButton(url: Self.termsOfUseURL) {
                    SettingsGlyphLabel(title: "Terms", systemName: "doc.text.fill", tint: .gray)
                }
                LegalDocumentButton(url: Self.privacyPolicyURL) {
                    SettingsGlyphLabel(title: "Privacy", systemName: "hand.raised.fill", tint: .gray)
                }
                Link(destination: Self.appStoreWriteReviewURL) {
                    SettingsGlyphLabel(title: "Rate Unforgetty", systemName: "star.fill", tint: .yellow)
                }
            }
            .textCase(nil)

            Section("External Settings") {
                Button {
                    openNotificationSettings()
                } label: {
                    HStack {
                        SettingsGlyphLabel(title: "Notifications", systemName: "bell.fill", tint: .red)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    openAppSettings()
                } label: {
                    HStack {
                        SettingsGlyphLabel(title: "App Settings", systemName: "gear", tint: .gray)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .textCase(nil)

            Section("Debug") {
                HStack {
                    Text("User ID")
                    Spacer(minLength: 12)
                    Text(userID ?? "—")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if userID != nil {
                        Button {
                            Haptics.light()
                            #if canImport(UIKit)
                            UIPasteboard.general.string = userID
                            #endif
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(isStatusError ? .red : .secondary)
                }

                // Combines the old separate "reset identity" + "register" actions into one —
                // resetting without re-registering (or vice versa) was never actually useful on
                // its own, just two taps to do one thing.
                Button {
                    Task { await forceRegisterDevice() }
                } label: {
                    HStack {
                        Text("Force Register Device")
                        if isRegistering {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRegistering)

                #if DEBUG
                Button("Reset onboarding", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "hasFinishedOnboarding")
                    UserDefaults.standard.removeObject(forKey: "onboardingCurrentStep.v1")
                    flow.showOnboarding()
                }
                .disabled(isRegistering)
                #endif

                if let debugPayload {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(debugPayload)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = debugPayload
                            #endif
                        } label: {
                            Label("Copiar payload", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshAll()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.light()
                    Task { await refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .overlay {
            if isRegistering {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(statusMessage ?? "Registering…")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: isRegistering)
        .confirmationDialog(
            "Disconnect Spotify?",
            isPresented: $isShowingDisconnectSpotifyConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                Task { await spotify.disconnect() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await refreshAll()
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await refresh()
        await social.refresh()
        await spotify.refresh()
    }

    @ViewBuilder
    private var proBanner: some View {
        if store.isPremium {
            NavigationLink {
                SettingsPlanView()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unforgetty PRO")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("You're a Pro member")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        } else {
            Button {
                flow.showPaywall()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unforgetty PRO")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Unlock unlimited pings, scheduling ahead, and more")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var spotifyRow: some View {
        HStack(spacing: 12) {
            Image("spotify-icon")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(.circle)

            Text("Spotify")
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if spotify.isConnected {
                Button("Disconnect") {
                    isShowingDisconnectSpotifyConfirm = true
                }
                .foregroundStyle(.red)
            } else {
                Button {
                    Task { await spotify.connect() }
                } label: {
                    if spotify.isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(spotify.isBusy)
            }
        }
    }

    private func openNotificationSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func refresh() async {
        userID = await AppwritePushIdentity.shared.storedUserID()
    }

    /// Deletes the existing device identity and creates a completely new one, then re-registers
    /// it for push — replaces the old separate "reset identity" / "force register" buttons, which
    /// were never actually useful apart from each other.
    private func forceRegisterDevice() async {
        isRegistering = true
        isStatusError = false
        defer { isRegistering = false }

        statusMessage = "Resetting identity…"
        await AppwritePushIdentity.shared.resetIdentity()

        statusMessage = "Registering new user…"
        do {
            userID = try await AppwritePushIdentity.shared.ensureAnonymousUser()
        } catch {
            isStatusError = true
            statusMessage = "User error: \(error.localizedDescription)"
            debugPayload = await AppwritePushIdentity.shared.debugPayload()
            return
        }

        #if canImport(UIKit)
        statusMessage = "Requesting notification permission…"
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        guard granted else {
            isStatusError = true
            statusMessage = "Notifications not authorized, so no device could be registered."
            return
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        statusMessage = "Waiting for APNs to hand us a device token…"

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if await AppwritePushIdentity.shared.pushTargetID() != nil {
                statusMessage = "Device registered."
                return
            }
        }
        isStatusError = true
        statusMessage = "Still not registered after 10s — check the Xcode console for the APNs registration error."
        debugPayload = await AppwritePushIdentity.shared.debugPayload()
        #else
        statusMessage = "User OK (\(userID ?? "?"))."
        #endif
    }
}

/// Colored-circle-icon + title row, matching the app's established settings-row style.
private struct SettingsGlyphLabel: View {
    let title: String
    let systemName: String
    let tint: Color

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.75), tint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconGradient)
                Image(systemName: systemName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            Text(title)
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
    }
}

/// Minimal subscription-management page for Pro members — the App Store's own "Manage
/// Subscriptions" screen owns the actual billing/renewal details, this just links to it rather
/// than reimplementing subscription management here.
private struct SettingsPlanView: View {
    @EnvironmentObject private var store: ActivityStore
    private static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unforgetty PRO")
                            .font(.headline)
                        Text("Active")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Link(destination: Self.manageSubscriptionsURL) {
                    HStack {
                        Text("Manage Subscription")
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Restore Purchases") {
                    Task { await store.restorePurchases() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Your Plan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

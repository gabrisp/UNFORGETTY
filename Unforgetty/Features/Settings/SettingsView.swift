import SwiftUI
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var flow: AppFlowViewModel
    @State private var userID: String?
    @State private var targetID: String?
    @State private var statusMessage: String?
    @State private var isStatusError = false
    @State private var isRegistering = false
    @State private var debugPayload: String?
    @StateObject private var social = SocialSettingsModel()
    @StateObject private var spotify = SpotifySettingsModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SocialDetailView(model: social)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.title3)
                                .foregroundStyle(.yellow)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Social")
                                    .font(.headline)
                                Text(social.username.map { "@\($0)" } ?? "Sin username")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !social.pendingRequests.isEmpty {
                                Text("\(social.pendingRequests.count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 20, minHeight: 20)
                                    .background(Circle().fill(.red))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Debug") {
                    LabeledContent("User ID", value: userID ?? "—")
                    LabeledContent("Target ID", value: targetID ?? "—")

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(isStatusError ? .red : .secondary)
                    }

                    Button {
                        Task { await forceRegister() }
                    } label: {
                        HStack {
                            Text("Force Appwrite register")
                            if isRegistering {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRegistering)

                    Button("Reset identity", role: .destructive) {
                        Task {
                            await AppwritePushIdentity.shared.resetIdentity()
                            await refresh()
                            isStatusError = false
                            statusMessage = "Identity reset."
                        }
                    }
                    .disabled(isRegistering)

                    Button("Reset onboarding", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "hasFinishedOnboarding")
                        UserDefaults.standard.removeObject(forKey: "onboardingCurrentStep.v1")
                        dismiss()
                        flow.showOnboarding()
                    }
                    .disabled(isRegistering)

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

                SpotifySettingsSection(model: spotify)
            }
            .refreshable {
                await refresh()
                await social.refresh()
                await spotify.refresh()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isRegistering)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isRegistering)
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
        .task {
            await refresh()
            await social.refresh()
            await spotify.refresh()
        }
    }

    private func refresh() async {
        userID = await AppwritePushIdentity.shared.storedUserID()
        targetID = await AppwritePushIdentity.shared.pushTargetID()
    }

    private func forceRegister() async {
        isRegistering = true
        isStatusError = false
        defer { isRegistering = false }

        statusMessage = "Registering user…"
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
            statusMessage = "Notifications not authorized, so no target can be registered."
            return
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        statusMessage = "Waiting for APNs to hand us a device token…"

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let target = await AppwritePushIdentity.shared.pushTargetID() {
                targetID = target
                statusMessage = "Target registered."
                return
            }
        }
        isStatusError = true
        statusMessage = "Still no target after 10s — check the Xcode console for the APNs registration error."
        debugPayload = await AppwritePushIdentity.shared.debugPayload()
        #else
        statusMessage = "User OK (\(userID ?? "?"))."
        #endif
    }
}

import SwiftUI
import Combine

@MainActor
final class SocialSettingsModel: ObservableObject {
    @Published var username: String?
    @Published var usernameInput = ""
    @Published var isEditingUsername = false
    @Published var friends: [SocialRepository.Friend] = []
    @Published var pendingRequests: [SocialRepository.PendingRequest] = []
    @Published var addFriendInput = ""
    @Published var statusMessage: String?
    @Published var isStatusError = false
    @Published var isBusy = false

    func refresh() async {
        username = try? await SocialRepository.shared.myUsername()
        friends = (try? await SocialRepository.shared.listFriends()) ?? []
        pendingRequests = (try? await SocialRepository.shared.listPendingRequests()) ?? []
        // Safety net for the same race claimUsername() closes below: if ActivityKit ever handed
        // us a push-to-start token before this device had a Profile document yet (or any other
        // ordering hiccup), the backend silently drops it — there's no error to react to, so the
        // only way to recover is to just keep re-sending the locally cached token whenever we
        // know a username now exists.
        if username != nil, let cachedToken = LiveActivityController.pushToStartToken() {
            try? await SocialRepository.shared.updatePushToken(cachedToken)
        }
    }

    func claimUsername() async {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isBusy = true
        isStatusError = false
        defer { isBusy = false }
        do {
            let claimed = try await SocialRepository.shared.claimUsername(trimmed)
            username = claimed
            usernameInput = ""
            isEditingUsername = false
            statusMessage = "Guardado como @\(claimed)."
            // updatePushToken silently no-ops server-side if this device's Profile didn't exist
            // yet — which, until the line above, it never did. Re-send the token we already have
            // cached locally (ActivityKit's pushToStartTokenUpdates may have fired long before
            // this claim, or may not fire again for a long time) now that the profile is real.
            if let cachedToken = LiveActivityController.pushToStartToken() {
                try? await SocialRepository.shared.updatePushToken(cachedToken)
            }
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
    }

    func sendFriendRequest() async {
        let trimmed = addFriendInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let username, !trimmed.isEmpty else { return }
        isBusy = true
        isStatusError = false
        defer { isBusy = false }
        do {
            let status = try await SocialRepository.shared.sendFriendRequest(fromUsername: username, toUsername: trimmed)
            switch status {
            case "requested": statusMessage = "Solicitud enviada a @\(trimmed)."
            case "already_friends": statusMessage = "Ya sois amigos."
            default: statusMessage = "Ya hay una solicitud pendiente."
            }
            addFriendInput = ""
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
    }

    func respond(_ request: SocialRepository.PendingRequest, accept: Bool) async {
        isBusy = true
        isStatusError = false
        defer { isBusy = false }
        do {
            try await SocialRepository.shared.respondFriendRequest(requestID: request.requestID, accept: accept)
            await refresh()
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friend: SocialRepository.Friend) async {
        isBusy = true
        isStatusError = false
        defer { isBusy = false }
        do {
            try await SocialRepository.shared.removeFriend(userID: friend.userID)
            friends.removeAll { $0.id == friend.id }
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
    }
}

/// Pushed from the untitled "Social" mini-banner in `SettingsView` — the same management surface
/// (requests, editable username, friends with revoke) is also reachable inline from the
/// friend-picker sub-sheet in the edit flow; this is just the dedicated full-screen version.
struct SocialDetailView: View {
    @ObservedObject var model: SocialSettingsModel

    var body: some View {
        List {
            SocialSettingsSection(model: model)
        }
        .navigationTitle("Social")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
    }
}

struct SocialSettingsSection: View {
    @ObservedObject var model: SocialSettingsModel

    var body: some View {
        Section("Username") {
            if let username = model.username, !model.isEditingUsername {
                HStack {
                    LabeledContent("Tu username", value: "@\(username)")
                    Button("Editar") {
                        model.usernameInput = username
                        model.isEditingUsername = true
                    }
                }
            } else {
                HStack {
                    Text("@")
                        .foregroundStyle(.secondary)
                    TextField("username", text: $model.usernameInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Guardar") {
                        Task { await model.claimUsername() }
                    }
                    .disabled(model.usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)

                    if model.username != nil {
                        Button("Cancelar", role: .cancel) {
                            model.isEditingUsername = false
                        }
                    }
                }
            }
        }

        if !model.pendingRequests.isEmpty {
            Section("Solicitudes pendientes") {
                ForEach(model.pendingRequests) { request in
                    HStack {
                        Text("@\(request.fromUsername)")
                        Spacer()
                        Button("Aceptar") {
                            Task { await model.respond(request, accept: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)

                        Button("Rechazar", role: .destructive) {
                            Task { await model.respond(request, accept: false) }
                        }
                        .disabled(model.isBusy)
                    }
                }
            }
        }

        Section("Amigos") {
            if model.friends.isEmpty {
                Text("Todavía no tienes amigos.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.friends) { friend in
                    HStack {
                        Text("@\(friend.username)")
                        Spacer()
                        Button(role: .destructive) {
                            Task { await model.removeFriend(friend) }
                        } label: {
                            Image(systemName: "person.fill.xmark")
                        }
                        .disabled(model.isBusy)
                    }
                }
            }

            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("username de tu amigo", text: $model.addFriendInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Add") {
                    Task { await model.sendFriendRequest() }
                }
                .disabled(model.username == nil || model.addFriendInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
            }

            if model.username == nil {
                Text("Necesitas un username antes de añadir amigos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(model.isStatusError ? .red : .secondary)
            }
        }
    }
}

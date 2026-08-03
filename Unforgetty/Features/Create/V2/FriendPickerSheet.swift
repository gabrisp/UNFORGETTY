import SwiftUI

struct FriendPickerSheet: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    let onDone: () -> Void

    @State private var usernameInput = ""
    @State private var isClaimingUsername = false
    @State private var claimError: String?

    @State private var pendingRequests: [SocialRepository.PendingRequest] = []
    @State private var query = ""
    @State private var lookupResult: SocialRepository.UsernameLookup?
    @State private var isSendingRequest = false
    @State private var requestStatusMessage: String?
    @State private var errorMessage: String?

    private let friendsDisplayLimit = 20

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.myUsername == nil {
                        claimUsernameSection
                    } else {
                        if !pendingRequests.isEmpty {
                            requestsSection
                        }
                        friendsSection

                        if !viewModel.sendToFriendUsernames.isEmpty {
                            editorSection("Mensaje (opcional)") {
                                TextField("Escribe algo…", text: $viewModel.friendMessage, axis: .vertical)
                                    .lineLimit(1...4)

                                ColorPicker("Color del botón de enviar", selection: viewModel.hexBinding(\.friendSendButtonColorHex), supportsOpacity: false)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Enviar a un amigo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onDone) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .foregroundStyle(.white)
        .tint(.yellow)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadFriends()
            pendingRequests = (try? await SocialRepository.shared.listPendingRequests()) ?? []
        }
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else {
                lookupResult = nil
                return
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            lookupResult = try? await SocialRepository.shared.lookupUsername(trimmed)
        }
    }

    private var claimUsernameSection: some View {
        editorSection("Necesitas un username") {
            HStack(spacing: 8) {
                Text("@")
                    .foregroundStyle(.white.opacity(0.5))
                TextField("username", text: $usernameInput)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Guardar") {
                    Task {
                        Haptics.light()
                        await claimUsername()
                    }
                }
                .disabled(usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isClaimingUsername)
            }

            if let claimError {
                Text(claimError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var requestsSection: some View {
        editorSection("Solicitudes") {
            ForEach(pendingRequests) { request in
                HStack {
                    Text("@\(request.fromUsername)")
                    Spacer()
                    Button("Aceptar") {
                        Task {
                            Haptics.selection()
                            await respond(request, accept: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Rechazar", role: .destructive) {
                        Task {
                            Haptics.selection()
                            await respond(request, accept: false)
                        }
                    }
                }

                if request.id != pendingRequests.last?.id {
                    Divider().overlay(.white.opacity(0.1))
                }
            }
        }
    }

    private var friendsSection: some View {
        editorSection("Amigos (máx \(CreateActivityV2EditViewModel.maxFriendRecipients))") {
            TextField("Buscar por username", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(.white.opacity(0.1), in: .rect(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }

            if viewModel.friends.isEmpty, lookupResult == nil {
                Text("Todavía no tienes amigos. Búscalos arriba por username.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(displayedFriends) { friend in
                friendRow(friend)
            }

            if viewModel.friends.count > friendsDisplayLimit && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("+\(viewModel.friends.count - friendsDisplayLimit) más — busca por username para encontrarlos")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            searchResultRow
        }
    }

    private var displayedFriends: [SocialRepository.Friend] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return Array(viewModel.friends.prefix(friendsDisplayLimit)) }
        return viewModel.friends.filter { $0.username.lowercased().contains(trimmed) }
    }

    @ViewBuilder
    private var searchResultRow: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty, let lookupResult, !displayedFriends.contains(where: { $0.username.lowercased() == trimmed }) {
            if lookupResult.found, let userID = lookupResult.userID {
                HStack {
                    Text("@\(trimmed)")
                    Spacer()
                    Button("Solicitar") {
                        Task {
                            Haptics.selection()
                            await sendRequest(toUsername: trimmed, userID: userID)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSendingRequest)
                }
            } else {
                Text("No se ha encontrado ese usuario.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let requestStatusMessage {
                Text(requestStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func friendRow(_ friend: SocialRepository.Friend) -> some View {
        HStack {
            Button {
                Haptics.selection()
                toggle(friend.username)
            } label: {
                HStack {
                    Text("@\(friend.username)")
                    Spacer()
                    if viewModel.sendToFriendUsernames.contains(friend.username) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.yellow)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                Task {
                    Haptics.light()
                    await viewModel.removeFriend(friend)
                }
            } label: {
                Image(systemName: "person.fill.xmark")
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }

    private func editorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .textCase(.uppercase)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func toggle(_ username: String) {
        if let index = viewModel.sendToFriendUsernames.firstIndex(of: username) {
            viewModel.sendToFriendUsernames.remove(at: index)
        } else {
            guard viewModel.sendToFriendUsernames.count < CreateActivityV2EditViewModel.maxFriendRecipients else { return }
            viewModel.sendToFriendUsernames.append(username)
        }
    }

    private func claimUsername() async {
        isClaimingUsername = true
        claimError = nil
        defer { isClaimingUsername = false }
        let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard await viewModel.claimUsername(trimmed) else {
            claimError = viewModel.errorMessage
            return
        }
        usernameInput = ""
    }

    private func respond(_ request: SocialRepository.PendingRequest, accept: Bool) async {
        do {
            try await SocialRepository.shared.respondFriendRequest(requestID: request.requestID, accept: accept)
            pendingRequests.removeAll { $0.id == request.id }
            if accept { await viewModel.loadFriends() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendRequest(toUsername: String, userID: String) async {
        guard let myUsername = viewModel.myUsername else { return }
        isSendingRequest = true
        defer { isSendingRequest = false }
        do {
            let status = try await SocialRepository.shared.sendFriendRequest(fromUsername: myUsername, toUsername: toUsername)
            switch status {
            case "requested": requestStatusMessage = "Solicitud enviada."
            case "already_friends":
                requestStatusMessage = nil
                await viewModel.loadFriends()
            default: requestStatusMessage = "Ya hay una solicitud pendiente."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

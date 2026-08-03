import SwiftUI

/// Step 1 of the friend-send flow: pick who to send to. The search field sits bare at the top,
/// outside any boxed section (matching MusicPickerSheet's layout, not the old boxed-in version).
/// While not actively searching, friends are split into three sections — Seleccionados (only
/// shown once at least one is picked), Recientes (device-local "sent to before" history), and
/// Todos (everyone else, capped) — tapping a row in Recientes/Todos moves it into Seleccionados,
/// tapping it there moves it back out. The X cancels the whole flow; the checkmark (only enabled
/// with at least one recipient selected) advances to step 2 (`FriendMessageComposeSheet`), where
/// the message and send-button color are actually set.
struct FriendPickerSheet: View {
    @ObservedObject var viewModel: CreateActivityV2EditViewModel
    let onCancel: () -> Void

    @State private var usernameInput = ""
    @State private var isClaimingUsername = false
    @State private var claimError: String?

    @State private var pendingRequests: [SocialRepository.PendingRequest] = []
    @State private var query = ""
    @State private var lookupResult: SocialRepository.UsernameLookup?
    @State private var isSendingRequest = false
    @State private var requestStatusMessage: String?
    @State private var errorMessage: String?
    @State private var showsAllRecent = false
    @State private var showsAllFriends = false
    @State private var isRefreshing = false

    private let sectionDisplayLimit = 10

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.myUsername == nil {
                        claimUsernameSection
                    } else {
                        searchField

                        if !pendingRequests.isEmpty {
                            requestsSection
                        }

                        if isSearching {
                            searchResultsSection
                        } else {
                            browsingSections
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    // A friend request you sent gets accepted on the *other* person's device —
                    // nothing pushes that back to you, so there's no way to know without asking
                    // again. This is that ask, without needing to close and reopen the whole sheet.
                    Button {
                        Haptics.light()
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Haptics.light()
                        withAnimation(.snappy) {
                            viewModel.editSubSheet = .friendMessage
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.sendToFriendUsernames.isEmpty)
                }
            }
        }
        .foregroundStyle(.white)
        .tint(.yellow)
        .preferredColorScheme(.dark)
        .task {
            await refresh()
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

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchField: some View {
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

    // MARK: - Browsing (query empty): Seleccionados / Recientes / Todos

    @ViewBuilder
    private var browsingSections: some View {
        if viewModel.friends.isEmpty {
            Text("Todavía no tienes amigos. Búscalos arriba por username.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if !selectedFriends.isEmpty {
            editorSection("Seleccionados (\(selectedFriends.count)/\(CreateActivityV2EditViewModel.maxFriendRecipients))") {
                friendRows(selectedFriends)
            }
        }

        if !recentFriends.isEmpty {
            editorSection("Recientes") {
                cappedSection(recentFriends, isExpanded: $showsAllRecent)
            }
        }

        if !remainingFriends.isEmpty {
            editorSection("Todos") {
                cappedSection(remainingFriends, isExpanded: $showsAllFriends)
            }
        }
    }

    /// Same cap/expand treatment for both Recientes and Todos: show up to `sectionDisplayLimit`,
    /// then a "Ver más" button reveals the rest — the search field up top is the other way to find
    /// someone without expanding, for whichever section that's actually faster in.
    @ViewBuilder
    private func cappedSection(_ friends: [SocialRepository.Friend], isExpanded: Binding<Bool>) -> some View {
        let shown = isExpanded.wrappedValue ? friends : Array(friends.prefix(sectionDisplayLimit))
        friendRows(shown)

        if friends.count > sectionDisplayLimit && !isExpanded.wrappedValue {
            Button("Ver \(friends.count - sectionDisplayLimit) más") {
                Haptics.light()
                isExpanded.wrappedValue = true
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private var selectedFriends: [SocialRepository.Friend] {
        viewModel.sendToFriendUsernames.compactMap { username in
            viewModel.friends.first { $0.username == username }
        }
    }

    private var recentFriends: [SocialRepository.Friend] {
        let selectedUsernames = Set(viewModel.sendToFriendUsernames)
        let recentUsernames = RecentFriendRecipients.recent()
        return recentUsernames.compactMap { username in
            guard !selectedUsernames.contains(username) else { return nil }
            return viewModel.friends.first { $0.username == username }
        }
    }

    private var remainingFriends: [SocialRepository.Friend] {
        let excluded = Set(viewModel.sendToFriendUsernames).union(recentFriends.map(\.username))
        return viewModel.friends.filter { !excluded.contains($0.username) }
    }

    private func friendRows(_ friends: [SocialRepository.Friend]) -> some View {
        ForEach(friends) { friend in
            friendRow(friend)

            if friend.id != friends.last?.id {
                Divider().overlay(.white.opacity(0.1))
            }
        }
    }

    // MARK: - Searching (query non-empty): flat filtered list + add-new-friend prompt

    private var searchResultsSection: some View {
        editorSection("Resultados") {
            if displayedSearchFriends.isEmpty, lookupResult == nil {
                Text("Buscando…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            friendRows(displayedSearchFriends)
            searchResultRow
        }
    }

    private var displayedSearchFriends: [SocialRepository.Friend] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.friends.filter { $0.username.lowercased().contains(trimmed) }
    }

    @ViewBuilder
    private var searchResultRow: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty, let lookupResult, !displayedSearchFriends.contains(where: { $0.username.lowercased() == trimmed }) {
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

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await viewModel.loadFriends()
        pendingRequests = (try? await SocialRepository.shared.listPendingRequests()) ?? []
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

import Foundation

/// Friends/username backend, mirroring AppwritePushIdentity's function-call plumbing but with
/// mixed-type payloads (Appwrite Functions, action-based dispatch, no Appwrite SDK dependency).
actor SocialRepository {
    static let shared = SocialRepository()

    struct Friend: Identifiable, Decodable {
        let userID: String
        let username: String
        var id: String { userID }
    }

    struct PendingRequest: Identifiable, Decodable {
        let requestID: String
        let fromUsername: String
        var id: String { requestID }
    }

    @discardableResult
    func claimUsername(_ username: String) async throws -> String {
        let response: UsernameResponse = try await execute(action: "claimUsername", extra: ["username": username])
        guard let claimed = response.username else { throw SocialError.requestFailed(detail: "empty_username") }
        return claimed
    }

    func myUsername() async throws -> String? {
        let response: UsernameResponse = try await execute(action: "myUsername")
        return response.username
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let response: SearchResponse = try await execute(action: "searchUsername", extra: ["username": username])
        return !response.found
    }

    struct UsernameLookup { let found: Bool; let userID: String? }

    /// Distinguishes "no such user" from "exists, not yet a friend" from "exists, already a
    /// friend" — `isUsernameAvailable` collapses all of that into a single bool, which is only
    /// useful for the claim-a-username flow, not for searching people.
    func lookupUsername(_ username: String) async throws -> UsernameLookup {
        let response: SearchResponse = try await execute(action: "searchUsername", extra: ["username": username])
        return UsernameLookup(found: response.found, userID: response.userID)
    }

    func removeFriend(userID friendUserID: String) async throws {
        let _: StatusResponse = try await execute(action: "removeFriend", extra: ["friendUserID": friendUserID])
    }

    @discardableResult
    func sendFriendRequest(fromUsername: String, toUsername: String) async throws -> String {
        let response: StatusResponse = try await execute(action: "sendFriendRequest", extra: ["fromUsername": fromUsername, "toUsername": toUsername])
        return response.status ?? "unknown"
    }

    func respondFriendRequest(requestID: String, accept: Bool) async throws {
        let _: StatusResponse = try await execute(action: "respondFriendRequest", extra: ["requestID": requestID, "accept": accept])
    }

    func listFriends() async throws -> [Friend] {
        let response: FriendsResponse = try await execute(action: "listFriends")
        return response.friends
    }

    func listPendingRequests() async throws -> [PendingRequest] {
        let response: RequestsResponse = try await execute(action: "listPendingRequests")
        return response.requests
    }

    func updatePushToken(_ token: String) async throws {
        let _: StatusResponse = try await execute(action: "updatePushToken", extra: ["pushToStartToken": token])
    }

    /// Called by the recipient of a friend ping once ActivityKit hands back a per-activity update
    /// push token, so a later resend from the sender can target this specific running activity
    /// with `.update` instead of starting a duplicate. `message` seeds the server's "did the
    /// message change since last send" comparison for the very first registration.
    func registerActivityUpdateToken(notificationID: String, activityUpdateToken: String, message: String?) async throws {
        var extra: [String: Any] = ["notificationID": notificationID, "activityUpdateToken": activityUpdateToken]
        if let message { extra["message"] = message }
        let _: StatusResponse = try await execute(action: "registerActivityUpdateToken", extra: extra)
    }

    /// Uploads a `.image`-kind activity's background photo to the "images" Storage bucket so a
    /// friend's device can actually load it — raw bytes can't fit in the push payload. Returns the
    /// resulting file's public view URL.
    func uploadImage(_ data: Data) async throws -> String {
        let response: UploadImageResponse = try await execute(action: "uploadImage", extra: [
            "imageBase64": data.base64EncodedString()
        ])
        guard !response.url.isEmpty else { throw SocialError.requestFailed(detail: "empty_upload_url") }
        return response.url
    }

    /// Split out of sendToFriend's call site — a single `[String: Any]` literal this size (30+
    /// keys, after adding imageURL) previously pushed the type-checker into the same
    /// "unable to type-check in reasonable time" failure mode PaywallShowcaseCardView.body hit
    /// earlier — annotating this as its own statement with an explicit type keeps each expression
    /// small enough to check quickly regardless of how many fields FriendActivitySnapshot grows to.
    private func snapshotPayload(_ snapshot: FriendActivitySnapshot) -> [String: Any] {
        [
            "kind": snapshot.kind,
            "imageURL": snapshot.imageURL ?? "",
            "friendSendButtonColorHex": snapshot.friendSendButtonColorHex,
            "body": snapshot.body,
            "backgroundHex": snapshot.backgroundHex,
            "backgroundMode": snapshot.backgroundMode,
            "gradientStartHex": snapshot.gradientStartHex,
            "gradientEndHex": snapshot.gradientEndHex,
            "gradientKind": snapshot.gradientKind,
            "gradientAngle": snapshot.gradientAngle,
            "gradientCenterX": snapshot.gradientCenterX,
            "gradientCenterY": snapshot.gradientCenterY,
            "textHex": snapshot.textHex,
            "font": snapshot.font,
            "textSize": snapshot.textSize,
            "alignment": snapshot.alignment,
            "verticalAlignment": snapshot.verticalAlignment,
            "lineSpacingMultiplier": snapshot.lineSpacingMultiplier,
            "borderHex": snapshot.borderHex,
            "borderWidth": snapshot.borderWidth,
            "musicTitle": snapshot.musicTitle ?? "",
            "musicArtist": snapshot.musicArtist ?? "",
            "musicAlbum": snapshot.musicAlbum ?? "",
            "musicSpotifyTrackID": snapshot.musicSpotifyTrackID ?? "",
            "musicSpotifyURL": snapshot.musicSpotifyURL ?? "",
            "musicAlbumArtURL": snapshot.musicAlbumArtURL ?? "",
            "musicLayout": snapshot.musicLayout,
            "musicBorderEnabled": snapshot.musicBorderEnabled,
            "musicBorderHex": snapshot.musicBorderHex,
            "musicShowsTitle": snapshot.musicShowsTitle,
            "musicShowsArtist": snapshot.musicShowsArtist,
            "musicShowsAlbum": snapshot.musicShowsAlbum,
            "musicArtPosition": snapshot.musicArtPosition
        ]
    }

    func sendToFriend(fromUsername: String, toUsername: String, message: String, notificationID: String, snapshot: FriendActivitySnapshot) async throws {
        let _: StatusResponse = try await execute(action: "sendToFriend", extra: [
            "fromUsername": fromUsername,
            "toUsername": toUsername,
            "message": message,
            "notificationID": notificationID,
            "snapshot": snapshotPayload(snapshot)
        ])
    }

    /// A cached identity can go stale server-side (e.g. its Appwrite user was deleted) with no
    /// local signal that it happened — `ensureAnonymousUser()` only checks that the cache is
    /// *shaped* right, not that the account still exists. Appwrite rejects such a session with a
    /// flat HTTP 401 at the execute-permission layer (before our function even runs), so that's
    /// the signal: wipe the identity and mint a fresh one, once, transparently.
    private func execute<Response: Decodable>(action: String, extra: [String: Any] = [:], isRetry: Bool = false) async throws -> Response {
        guard
            let endpointValue = Bundle.main.object(forInfoDictionaryKey: "AppwritePublicEndpoint") as? String,
            let endpoint = URL(string: endpointValue),
            let projectID = Bundle.main.object(forInfoDictionaryKey: "AppwriteProjectID") as? String,
            let functionID = Bundle.main.object(forInfoDictionaryKey: "AppwriteSocialFunctionID") as? String
        else { throw SocialError.missingConfiguration }

        let userID = try await AppwritePushIdentity.shared.ensureAnonymousUser()
        var payload: [String: Any] = ["action": action, "userID": userID]
        for (key, value) in extra { payload[key] = value }

        var request = URLRequest(url: endpoint.appending(path: "functions/\(functionID)/executions"))
        request.httpMethod = "POST"
        request.setValue(projectID, forHTTPHeaderField: "X-Appwrite-Project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Functions require `execute: users` (not the wide-open `any`), so the caller must prove
        // it's an authenticated session — native clients can't use cookies, so Appwrite's
        // documented workaround is echoing back the `X-Fallback-Cookies` blob it handed us at
        // session-creation time (see AppwriteFunctions/anonymous-session).
        if let sessionCookie = await AppwritePushIdentity.shared.sessionSecretValue(), !sessionCookie.isEmpty {
            request.setValue(sessionCookie, forHTTPHeaderField: "X-Fallback-Cookies")
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "body": String(decoding: body, as: UTF8.self),
            "async": false,
            "headers": ["Content-Type": "application/json"]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if statusCode == 401, !isRetry {
                _ = try? await AppwritePushIdentity.shared.reauthenticate()
                return try await execute(action: action, extra: extra, isRetry: true)
            }
            throw SocialError.requestFailed(detail: "HTTP \(statusCode) creating execution")
        }

        let execution = try JSONDecoder().decode(FunctionExecution.self, from: data)
        guard let responseBody = execution.responseBody?.data(using: .utf8) else {
            throw SocialError.requestFailed(detail: "empty execution response body")
        }
        guard (execution.responseStatusCode ?? 500) >= 200, (execution.responseStatusCode ?? 500) < 300 else {
            let serverError = (try? JSONDecoder().decode(ErrorResponse.self, from: responseBody))?.error
            throw SocialError.requestFailed(detail: serverError ?? execution.responseBody ?? "unknown")
        }
        return try JSONDecoder().decode(Response.self, from: responseBody)
    }

    private struct FunctionExecution: Decodable {
        let responseBody: String?
        let responseStatusCode: Int?
    }

    private struct ErrorResponse: Decodable { let error: String? }
    private struct UsernameResponse: Decodable { let username: String? }
    private struct SearchResponse: Decodable { let found: Bool; let userID: String? }
    private struct StatusResponse: Decodable { let status: String? }
    private struct UploadImageResponse: Decodable { let url: String }
    private struct FriendsResponse: Decodable { let friends: [Friend] }
    private struct RequestsResponse: Decodable { let requests: [PendingRequest] }
}

enum SocialError: LocalizedError {
    case missingConfiguration
    case requestFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Falta la configuración de Appwrite."
        case .requestFailed(let detail): errorMessage(for: detail)
        }
    }

    private func errorMessage(for detail: String) -> String {
        switch detail {
        case "invalid_username": "Ese nombre de usuario no es válido (3-20 caracteres, minúsculas, números o _)."
        case "username_taken": "Ese nombre de usuario ya está en uso."
        case "user_not_found": "No existe ningún usuario con ese nombre."
        case "cannot_friend_yourself": "No puedes añadirte a ti mismo."
        case "not_friends": "Todavía no sois amigos."
        case "friend_has_no_device": "Tu amigo no tiene ningún dispositivo registrado todavía."
        case "not_your_request": "Esa solicitud no es tuya."
        default: "Fallo de Appwrite (\(detail))."
        }
    }
}

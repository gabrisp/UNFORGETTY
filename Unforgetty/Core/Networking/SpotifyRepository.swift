import Foundation

/// Spotify backend, mirroring SocialRepository's function-call plumbing exactly (Appwrite
/// Functions, action-based dispatch, no Spotify SDK dependency). The client never calls Spotify's
/// API directly — every action here is proxied through the `spotify` Appwrite Function, which
/// holds the client secret and per-user OAuth tokens.
actor SpotifyRepository {
    static let shared = SpotifyRepository()

    struct SpotifyTrack: Identifiable, Decodable {
        let id: String
        let name: String
        let artist: String
        let album: String
        let albumArtURL: String?
        let spotifyURL: String?
    }

    func status() async throws -> Bool {
        let response: StatusFlagResponse = try await execute(action: "spotifyStatus")
        return response.connected
    }

    func exchangeCode(code: String, codeVerifier: String, redirectURI: String) async throws {
        let _: StatusFlagResponse = try await execute(action: "exchangeSpotifyCode", extra: [
            "code": code,
            "codeVerifier": codeVerifier,
            "redirectURI": redirectURI
        ])
    }

    func disconnect() async throws {
        let _: DisconnectResponse = try await execute(action: "disconnectSpotify")
    }

    func search(query: String) async throws -> [SpotifyTrack] {
        let response: TracksResponse = try await execute(action: "searchTracks", extra: ["query": query])
        return response.tracks
    }

    func currentlyPlaying() async throws -> SpotifyTrack? {
        let response: CurrentlyPlayingResponse = try await execute(action: "currentlyPlaying")
        return response.playing ? response.track : nil
    }

    /// Self-heals a cached identity that's gone stale server-side (e.g. its Appwrite user was
    /// deleted) — Appwrite rejects that with a flat HTTP 401 at the execute-permission layer, so
    /// that's the signal to wipe and mint a fresh identity, once, transparently.
    private func execute<Response: Decodable>(action: String, extra: [String: Any] = [:], isRetry: Bool = false) async throws -> Response {
        guard
            let endpointValue = Bundle.main.object(forInfoDictionaryKey: "AppwritePublicEndpoint") as? String,
            let endpoint = URL(string: endpointValue),
            let projectID = Bundle.main.object(forInfoDictionaryKey: "AppwriteProjectID") as? String,
            let functionID = Bundle.main.object(forInfoDictionaryKey: "AppwriteSpotifyFunctionID") as? String
        else { throw SpotifyError.missingConfiguration }

        let userID = try await AppwritePushIdentity.shared.ensureAnonymousUser()
        var payload: [String: Any] = ["action": action, "userID": userID]
        for (key, value) in extra { payload[key] = value }

        var request = URLRequest(url: endpoint.appending(path: "functions/\(functionID)/executions"))
        request.httpMethod = "POST"
        request.setValue(projectID, forHTTPHeaderField: "X-Appwrite-Project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Functions require `execute: users` (not the wide-open `any`) — see SocialRepository's
        // matching comment for why `X-Fallback-Cookies` is the right header for native clients.
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
            throw SpotifyError.requestFailed(detail: "HTTP \(statusCode) creating execution")
        }

        let execution = try JSONDecoder().decode(FunctionExecution.self, from: data)
        guard let responseBody = execution.responseBody?.data(using: .utf8) else {
            throw SpotifyError.requestFailed(detail: "empty execution response body")
        }
        guard (execution.responseStatusCode ?? 500) >= 200, (execution.responseStatusCode ?? 500) < 300 else {
            let serverError = (try? JSONDecoder().decode(ErrorResponse.self, from: responseBody))?.error
            throw SpotifyError.requestFailed(detail: serverError ?? execution.responseBody ?? "unknown")
        }
        return try JSONDecoder().decode(Response.self, from: responseBody)
    }

    private struct FunctionExecution: Decodable {
        let responseBody: String?
        let responseStatusCode: Int?
    }

    private struct ErrorResponse: Decodable { let error: String? }
    private struct StatusFlagResponse: Decodable { let connected: Bool }
    private struct DisconnectResponse: Decodable { let disconnected: Bool }
    private struct TracksResponse: Decodable { let tracks: [SpotifyTrack] }
    private struct CurrentlyPlayingResponse: Decodable { let playing: Bool; let track: SpotifyTrack? }
}

enum SpotifyError: LocalizedError {
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
        case "not_connected": "Conecta tu cuenta de Spotify primero."
        case "nothing_playing": "No hay nada sonando ahora mismo."
        case "missing_query": "Escribe algo para buscar."
        default: "Fallo de Spotify (\(detail))."
        }
    }
}

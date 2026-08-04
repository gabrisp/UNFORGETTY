import SwiftUI
import Combine
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SpotifySettingsModel: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var statusMessage: String?
    @Published var isStatusError = false

    private static let redirectURI = "unforgetty://spotify-callback"

    func refresh() async {
        isConnected = (try? await SpotifyRepository.shared.status()) ?? false
    }

    func connect() async {
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
            !clientID.isEmpty
        else {
            isStatusError = true
            statusMessage = "Falta configurar el Client ID de Spotify."
            return
        }

        let codeVerifier = SpotifyPKCE.makeCodeVerifier()
        let codeChallenge = SpotifyPKCE.codeChallenge(for: codeVerifier)
        let state = SpotifyPKCE.makeState()

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "scope", value: "user-read-currently-playing"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authorizeURL = components.url else { return }

        isBusy = true
        isStatusError = false
        statusMessage = nil
        defer { isBusy = false }

        do {
            let callbackURL = try await authenticate(url: authorizeURL)
            let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            guard
                let returnedState = callbackComponents?.queryItems?.first(where: { $0.name == "state" })?.value,
                returnedState == state
            else { throw SpotifyError.requestFailed(detail: "state_mismatch") }
            guard let code = callbackComponents?.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw SpotifyError.requestFailed(detail: "missing_code")
            }
            try await SpotifyRepository.shared.exchangeCode(code: code, codeVerifier: codeVerifier, redirectURI: Self.redirectURI)
            isConnected = true
            statusMessage = "Cuenta de Spotify conectada."
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await SpotifyRepository.shared.disconnect()
            isConnected = false
            statusMessage = "Cuenta de Spotify desconectada."
            isStatusError = false
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
    }

    private var authSession: ASWebAuthenticationSession?

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "unforgetty") { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? SpotifyError.requestFailed(detail: "cancelled"))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            authSession = session
            session.start()
        }
    }
}

extension SpotifySettingsModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        ASPresentationAnchor()
        #endif
    }
}

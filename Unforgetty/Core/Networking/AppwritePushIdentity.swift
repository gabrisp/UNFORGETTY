import Foundation
import Security
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

actor AppwritePushIdentity {
    static let shared = AppwritePushIdentity()

    private let sessionKey = "appwrite.session.secret"
    private let userIDKey = "appwrite.user.id"
    private let targetIDKey = "appwrite.push.target.id"

    private var anonymousUserTask: Task<String, Error>?

    private struct AnonymousSession: Decodable {
        let userID: String
        let sessionCookie: String

        enum CodingKeys: String, CodingKey {
            case userID = "userId"
            case sessionCookie
        }
    }

    private struct PushTarget: Decodable {
        let userID: String

        enum CodingKeys: String, CodingKey {
            case userID = "userId"
        }
    }

    func ensureAnonymousUser() async throws -> String {
        // The cached session must be a real `X-Fallback-Cookies` JSON blob (starts with "{") —
        // installs from before that fix cached a raw Set-Cookie string instead, which
        // authenticates nothing. Treat that as "no session" so it gets silently replaced.
        if let userID = KeychainValue.read(userIDKey),
           let session = KeychainValue.read(sessionKey), session.hasPrefix("{") {
            NSLog("Unforgetty: ensureAnonymousUser found cached userID=%@, skipping network", userID)
            return userID
        }
        // Reuse the in-flight registration instead of racing: the bootstrap flow and the
        // push-registration flow both call this on cold start and could otherwise create two users.
        if let inFlight = anonymousUserTask {
            NSLog("Unforgetty: ensureAnonymousUser joining in-flight registration")
            return try await inFlight.value
        }
        NSLog("Unforgetty: ensureAnonymousUser has no cached identity, calling anonymous-session")
        let task = Task { try await createAnonymousUser() }
        anonymousUserTask = task
        defer { anonymousUserTask = nil }
        return try await task.value
    }

    func createAnonymousUser() async throws -> String {
        do {
            let session: AnonymousSession = try await executeFunction("anonymous-session", payload: [:])
            KeychainValue.save(session.userID, key: userIDKey)
            KeychainValue.save(session.sessionCookie, key: sessionKey)
            NSLog("Unforgetty: anonymous-session succeeded, userID=%@", session.userID)
            return session.userID
        } catch {
            NSLog("Unforgetty: anonymous-session FAILED: %@", (error as? LocalizedError)?.errorDescription ?? "\(error)")
            throw error
        }
    }

    func sessionSecretValue() -> String? {
        KeychainValue.read(sessionKey)
    }

    /// The Appwrite messaging target already registered for this install, if any. Never triggers registration.
    func pushTargetID() -> String? {
        KeychainValue.read(targetIDKey)
    }

    /// Actively (re)attempts registration instead of just reporting whatever's cached — call this
    /// right before something that actually needs a target (e.g. scheduling), not only at app
    /// launch, so a user who denied notifications and later enabled them in iOS Settings isn't
    /// stuck forever with no way to recover short of the Settings screen's debug button.
    func ensurePushTarget(timeout: TimeInterval = 6) async -> String? {
        if let cached = pushTargetID() { return cached }
        #if canImport(UIKit)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return nil }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let target = pushTargetID() { return target }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        #endif
        return pushTargetID()
    }

    /// The Appwrite anonymous user ID already stored in the Keychain, if any. Never triggers registration.
    func storedUserID() -> String? {
        KeychainValue.read(userIDKey)
    }

    /// Clears the local identity so the next call to `ensureAnonymousUser`/`registerPushTarget`
    /// starts over. Does not delete anything server-side.
    func resetIdentity() {
        KeychainValue.delete(sessionKey)
        KeychainValue.delete(userIDKey)
        KeychainValue.delete(targetIDKey)
    }

    private var reauthenticateTask: Task<String, Error>?

    /// The self-heal path multiple repositories call after a 401 (see SocialRepository /
    /// SpotifyRepository). If each caller independently did `resetIdentity()` then
    /// `ensureAnonymousUser()`, concurrent 401s (e.g. several `.task`s firing at once on a screen
    /// appear) would race: caller B's reset can wipe the fresh identity caller A just created,
    /// each minting its own throwaway anonymous user. Routing every caller through one shared
    /// in-flight task means only the first one actually resets/recreates; the rest just await it.
    func reauthenticate() async throws -> String {
        if let inFlight = reauthenticateTask {
            return try await inFlight.value
        }
        let task = Task<String, Error> {
            KeychainValue.delete(sessionKey)
            KeychainValue.delete(userIDKey)
            KeychainValue.delete(targetIDKey)
            return try await createAnonymousUser()
        }
        reauthenticateTask = task
        defer { reauthenticateTask = nil }
        return try await task.value
    }

    /// Always makes the network call rather than trusting a cached `targetID` — a cached value
    /// only proves we registered *at some point*, not that the target (or its parent user) is
    /// still valid server-side, and this app's users have gotten deleted/reset independently of
    /// the local cache before. `register-push-target` is idempotent (409 = already registered),
    /// so re-calling it every time is safe and self-correcting instead of trusting stale state.
    func registerPushTarget(deviceToken: Data) async throws -> String {
        let userID = try await ensureAnonymousUser()

        guard let providerID = Bundle.main.object(forInfoDictionaryKey: "AppwriteAPNSProviderID") as? String,
              !providerID.isEmpty else {
            NSLog("Unforgetty: registerPushTarget missing AppwriteAPNSProviderID in Info.plist")
            throw AppwritePushIdentityError.missingProviderID
        }

        NSLog("Unforgetty: registerPushTarget calling register-push-target for userID=%@", userID)
        // targetId is always this user's own ID. We confirm success by reading back `userId` from
        // the created target (Appwrite's own resource id is `$id`, which needs no parsing here since
        // we already know it equals userID — but `userId` is a plain, unprefixed field we can assert on).
        do {
            let target: PushTarget = try await executeFunction("register-push-target", payload: [
                "sessionCookie": sessionSecret,
                "targetId": userID,
                "providerId": providerID,
                "identifier": deviceToken.map { String(format: "%02x", $0) }.joined(),
                "name": "Unforgetty Device"
            ])
            KeychainValue.save(target.userID, key: targetIDKey)
            NSLog("Unforgetty: register-push-target succeeded, targetID=%@", target.userID)
            return target.userID
        } catch AppwritePushIdentityError.functionError(let status, let body) where status == 409 && body.contains("user_target_already_exists") {
            KeychainValue.save(userID, key: targetIDKey)
            NSLog("Unforgetty: register-push-target: targetID=%@ already existed, adopting it", userID)
            return userID
        } catch {
            NSLog("Unforgetty: register-push-target FAILED: %@", (error as? LocalizedError)?.errorDescription ?? "\(error)")
            throw error
        }
    }

    private var sessionSecret: String {
        KeychainValue.read(sessionKey) ?? ""
    }

    /// Raw text of whatever the last `executeFunction` call actually got back — surfaced in
    /// Settings' Debug section (with a copy button) so a real payload can be pasted here instead
    /// of guessing from a symptom description.
    private(set) var lastDebugPayload: String?

    func debugPayload() -> String? { lastDebugPayload }

    private func executeFunction<Response: Decodable>(_ functionID: String, payload: [String: String]) async throws -> Response {
        guard
            let endpointValue = Bundle.main.object(forInfoDictionaryKey: "AppwritePublicEndpoint") as? String,
            let endpoint = URL(string: endpointValue),
            let projectID = Bundle.main.object(forInfoDictionaryKey: "AppwriteProjectID") as? String
        else { throw AppwritePushIdentityError.missingConfiguration }

        var request = URLRequest(url: endpoint.appending(path: "functions/\(functionID)/executions"))
        request.httpMethod = "POST"
        request.setValue(projectID, forHTTPHeaderField: "X-Appwrite-Project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "body": String(decoding: body, as: UTF8.self),
            "async": false,
            "headers": ["Content-Type": "application/json"]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            lastDebugPayload = "[\(functionID)] HTTP \(status) creating execution\n\(String(data: data, encoding: .utf8) ?? "")"
            throw AppwritePushIdentityError.requestFailed(detail: "HTTP \(status) creating execution")
        }

        let execution = try JSONDecoder().decode(FunctionExecution.self, from: data)
        lastDebugPayload = "[\(functionID)] HTTP \(execution.responseStatusCode ?? -1)\n\(execution.responseBody ?? "<empty>")"
        guard let responseBody = execution.responseBody?.data(using: .utf8) else {
            throw AppwritePushIdentityError.requestFailed(detail: "empty execution response body")
        }
        guard (execution.responseStatusCode ?? 500) >= 200,
              (execution.responseStatusCode ?? 500) < 300 else {
            throw AppwritePushIdentityError.functionError(status: execution.responseStatusCode ?? -1, body: execution.responseBody ?? "")
        }
        return try JSONDecoder().decode(Response.self, from: responseBody)
    }

    private struct FunctionExecution: Decodable {
        let responseBody: String?
        let responseStatusCode: Int?
    }
}

enum AppwritePushIdentityError: LocalizedError {
    case missingConfiguration
    case missingProviderID
    case requestFailed(detail: String)
    case functionError(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Falta la configuración de Appwrite."
        case .missingProviderID: "Falta el provider APNs de Appwrite."
        case .requestFailed(let detail): "Appwrite no pudo registrar el dispositivo (\(detail))."
        case .functionError(let status, let body): "Appwrite no pudo registrar el dispositivo (HTTP \(status): \(body))."
        }
    }
}

private enum KeychainValue {
    private static let service = "com.gabrisp.Unforgetty.appwrite"

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

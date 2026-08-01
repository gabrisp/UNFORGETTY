import Foundation

/// Thin API client for Appwrite Functions. It is deliberately independent of the Appwrite SDK.
actor AppwriteFunctionsRepository {
    static let shared = AppwriteFunctionsRepository()

    private let session: URLSession
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(session: URLSession = .shared) { self.session = session }

    func executeScheduler(_ payload: PrivateSchedulePayload) async throws {
        let functionID = try configuration().schedulerFunctionID
        try await execute(functionID: functionID, payload: payload)
    }

    func execute<Payload: Encodable>(functionID: String, payload: Payload) async throws {
        let config = try configuration()
        let payloadData = try encoder.encode(payload)

        // `async: false` so we actually see the function's real result — an accepted async
        // execution only means Appwrite queued it, not that validation or the DB write succeeded.
        // No session header: the function already has its own scoped API key, and a malformed
        // session header would take priority over that key server-side and silently break auth.
        let execution = FunctionExecutionRequest(
            body: String(decoding: payloadData, as: UTF8.self),
            async: false,
            headers: ["Content-Type": "application/json"]
        )
        var request = URLRequest(url: config.endpoint.appending(path: "functions/\(functionID)/executions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.projectID, forHTTPHeaderField: "X-Appwrite-Project")
        request.httpBody = try encoder.encode(execution)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            NSLog("Unforgetty: scheduler execution HTTP failed: %d", (response as? HTTPURLResponse)?.statusCode ?? -1)
            throw AppwriteFunctionError.requestFailed(detail: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1) creating execution")
        }

        let result = try JSONDecoder().decode(FunctionExecution.self, from: data)
        guard (result.responseStatusCode ?? 500) >= 200, (result.responseStatusCode ?? 500) < 300 else {
            NSLog("Unforgetty: scheduler function rejected the job: %d %@", result.responseStatusCode ?? -1, result.responseBody ?? "")
            throw AppwriteFunctionError.requestFailed(detail: "function returned \(result.responseStatusCode ?? -1): \(result.responseBody ?? "")")
        }
        NSLog("Unforgetty: scheduler accepted the job")
    }

    private func configuration() throws -> Configuration {
        guard
            let endpointValue = Bundle.main.object(forInfoDictionaryKey: "AppwritePublicEndpoint") as? String,
            let endpoint = URL(string: endpointValue),
            let projectID = Bundle.main.object(forInfoDictionaryKey: "AppwriteProjectID") as? String,
            let schedulerFunctionID = Bundle.main.object(forInfoDictionaryKey: "AppwriteSchedulerFunctionID") as? String,
            !projectID.isEmpty, !schedulerFunctionID.isEmpty
        else { throw AppwriteFunctionError.missingConfiguration }
        return Configuration(endpoint: endpoint, projectID: projectID, schedulerFunctionID: schedulerFunctionID)
    }
}

private struct Configuration { let endpoint: URL; let projectID: String; let schedulerFunctionID: String }
private nonisolated struct FunctionExecutionRequest: Encodable {
    let body: String
    let async: Bool
    let headers: [String: String]
}
private struct FunctionExecution: Decodable {
    let responseBody: String?
    let responseStatusCode: Int?
}
enum AppwriteFunctionError: LocalizedError {
    case missingConfiguration
    case requestFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Falta la configuración de Appwrite."
        case .requestFailed(let detail): "Appwrite no pudo aceptar la programación (\(detail))."
        }
    }
}

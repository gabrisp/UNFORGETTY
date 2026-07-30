import Foundation

/// Thin API client for Appwrite Functions. It is deliberately independent of the Appwrite SDK.
actor AppwriteFunctionsRepository {
    static let shared = AppwriteFunctionsRepository()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) { self.session = session }

    func executeScheduler(_ payload: PrivateSchedulePayload) async throws {
        let functionID = try configuration().schedulerFunctionID
        let _: SchedulerAcceptance = try await execute(functionID: functionID, payload: payload)
    }

    func execute<Payload: Encodable, Response: Decodable>(functionID: String, payload: Payload) async throws -> Response {
        let config = try configuration()
        let payloadData = try encoder.encode(payload)
        let execution = FunctionExecutionRequest(body: String(decoding: payloadData, as: UTF8.self), async: true)
        var request = URLRequest(url: config.endpoint.appending(path: "functions/\(functionID)/executions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.projectID, forHTTPHeaderField: "X-Appwrite-Project")
        request.httpBody = try encoder.encode(execution)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw AppwriteFunctionError.requestFailed }
        return try decoder.decode(Response.self, from: data)
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
private nonisolated struct FunctionExecutionRequest: Encodable { let body: String; let async: Bool }
private nonisolated struct SchedulerAcceptance: Decodable { let accepted: Bool? }
enum AppwriteFunctionError: LocalizedError { case missingConfiguration, requestFailed; var errorDescription: String? { switch self { case .missingConfiguration: "Falta la configuración de Appwrite."; case .requestFailed: "Appwrite no pudo aceptar la programación." } } }

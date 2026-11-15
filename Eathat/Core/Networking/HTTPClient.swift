import Foundation

/// One request to the API: a method, a path under the base URL, and an optional JSON body.
nonisolated struct HTTPRequest: Equatable, Sendable {
    var method: String
    var path: String
    var body: Data?

    static func get(_ path: String) -> Self {
        Self(method: "GET", path: path, body: nil)
    }

    static func post(_ path: String, body: Data? = nil) -> Self {
        Self(method: "POST", path: path, body: body)
    }

    static func delete(_ path: String) -> Self {
        Self(method: "DELETE", path: path, body: nil)
    }
}

nonisolated enum APIError: Error, Equatable, LocalizedError {
    /// The server refused the request; `message` is its explanation, when it gave one.
    case status(Int, message: String?)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case let .status(code, message):
            message ?? "Le serveur a répondu \(code)."

        case .notConfigured:
            "La clé de l'API manque (Config/Secrets.xcconfig)."
        }
    }
}

nonisolated protocol HTTPClient: Sendable {
    /// Sends `request` and returns the body of a 2xx answer; anything else throws an `APIError`.
    func send(_ request: HTTPRequest) async throws -> Data
}

/// The real client: `URLSession`, the base URL and the app's key.
nonisolated struct URLSessionHTTPClient: HTTPClient {
    let baseURL: URL
    let apiKey: String
    var session: URLSession = .shared

    private struct ErrorBody: Decodable {
        let message: String?
    }

    func send(_ request: HTTPRequest) async throws -> Data {
        guard !apiKey.isEmpty else { throw APIError.notConfigured }
        var urlRequest = URLRequest(url: baseURL.appending(path: request.path))
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: urlRequest)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw APIError.status(code, message: try? JSONDecoder().decode(ErrorBody.self, from: data).message)
        }
        return data
    }
}

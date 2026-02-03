import Foundation

actor APIClient {
    static let shared = APIClient()

    static let serverURLKey = "serverURL"
    static let defaultServerURL = ""

    private var baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    var accessToken: String?

    init() {
        let stored = UserDefaults.standard.string(forKey: APIClient.serverURLKey)
        self.baseURL = stored ?? APIClient.defaultServerURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }

    func setToken(_ token: String?) {
        self.accessToken = token
    }

    func updateBaseURL(_ url: String) {
        self.baseURL = url
        UserDefaults.standard.set(url, forKey: APIClient.serverURLKey)
    }

    func getBaseURL() -> String {
        return baseURL
    }

    var isConfigured: Bool {
        let url = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? ""
        return !url.isEmpty
    }

    func testConnection(to urlString: String) async throws {
        guard let url = URL(string: "\(urlString)/api/v1/repositories?per_page=1") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: Data())
        }
    }

    func request<T: Decodable & Sendable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return try decoder.decode(T.self, from: data)
    }

    func buildURL(_ path: String) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        return URL(string: "\(baseURL)\(path)")
    }

    func buildDownloadURL(repoKey: String, artifactPath: String) -> URL? {
        let encoded = artifactPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artifactPath
        return URL(string: "\(baseURL)/api/v1/repositories/\(repoKey)/artifacts/\(encoded)/download")
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .httpError(let code, _): return "HTTP error \(code)"
        }
    }
}

import Foundation

/// URLSession delegate that accepts self-signed certificates for self-hosted servers.
private final class SelfSignedCertDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

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
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config, delegate: SelfSignedCertDelegate(), delegateQueue: nil)
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
        guard let url = URL(string: "\(urlString)/health") else {
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

    /// Fire a request where the response body is empty or can be ignored.
    func requestVoid(
        _ endpoint: String,
        method: String = "POST",
        body: (any Encodable)? = nil
    ) async throws {
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
    }

    func buildURL(_ path: String) -> URL? {
        guard !baseURL.isEmpty else { return nil }
        return URL(string: "\(baseURL)\(path)")
    }

    func buildDownloadURL(repoKey: String, artifactPath: String) -> URL? {
        let encoded = artifactPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artifactPath
        return URL(string: "\(baseURL)/api/v1/repositories/\(repoKey)/artifacts/\(encoded)/download")
    }

    // MARK: - TOTP

    func totpSetup() async throws -> TotpSetupResponse {
        try await request("/api/v1/auth/totp/setup", method: "POST")
    }

    func totpEnable(code: String) async throws -> TotpEnableResponse {
        try await request("/api/v1/auth/totp/enable", method: "POST", body: TotpCodeRequest(code: code))
    }

    func totpVerify(totpToken: String, code: String) async throws -> LoginResponse {
        try await request(
            "/api/v1/auth/totp/verify",
            method: "POST",
            body: TotpVerifyRequest(totpToken: totpToken, code: code)
        )
    }

    func totpDisable(password: String, code: String) async throws {
        try await requestVoid(
            "/api/v1/auth/totp/disable",
            method: "POST",
            body: TotpDisableRequest(password: password, code: code)
        )
    }

    // MARK: - Password

    func changeUserPassword(userId: String, currentPassword: String, newPassword: String) async throws {
        try await requestVoid(
            "/api/v1/users/\(userId)/password",
            method: "POST",
            body: ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        )
    }

    // MARK: - Profile

    func getProfile() async throws -> ProfileResponse {
        try await request("/api/v1/auth/me")
    }

    func updateProfile(displayName: String?, email: String?) async throws -> ProfileResponse {
        try await request(
            "/api/v1/profile",
            method: "PUT",
            body: UpdateProfileRequest(displayName: displayName, email: email)
        )
    }

    // MARK: - API Keys

    func listApiKeys() async throws -> [ApiKey] {
        let response: ApiKeysListResponse = try await request("/api/v1/profile/api-keys")
        return response.apiKeys
    }

    func createApiKey(name: String, scopes: [String], expiresInDays: Int?) async throws -> CreateApiKeyResponse {
        try await request(
            "/api/v1/profile/api-keys",
            method: "POST",
            body: CreateApiKeyRequest(name: name, expiresInDays: expiresInDays, scopes: scopes)
        )
    }

    func deleteApiKey(_ id: String) async throws {
        try await requestVoid("/api/v1/profile/api-keys/\(id)", method: "DELETE")
    }

    // MARK: - Access Tokens

    func listAccessTokens() async throws -> [AccessToken] {
        let response: AccessTokensListResponse = try await request("/api/v1/profile/access-tokens")
        return response.accessTokens
    }

    func createAccessToken(name: String, scopes: [String], expiresInDays: Int?) async throws -> CreateAccessTokenResponse {
        try await request(
            "/api/v1/profile/access-tokens",
            method: "POST",
            body: CreateAccessTokenRequest(name: name, expiresInDays: expiresInDays, scopes: scopes)
        )
    }

    func deleteAccessToken(_ id: String) async throws {
        try await requestVoid("/api/v1/profile/access-tokens/\(id)", method: "DELETE")
    }

    // MARK: - Staging Repositories

    func listStagingRepos() async throws -> [StagingRepository] {
        let response: StagingRepositoryListResponse = try await request("/api/v1/staging/repositories")
        return response.items
    }

    func listStagingArtifacts(repoKey: String) async throws -> [StagingArtifact] {
        let response: StagingArtifactListResponse = try await request(
            "/api/v1/staging/repositories/\(repoKey)/artifacts?per_page=100"
        )
        return response.items
    }

    func promoteArtifact(repoKey: String, artifactId: String, request: PromotionRequest) async throws -> PromotionResponse {
        try await self.request(
            "/api/v1/staging/repositories/\(repoKey)/artifacts/\(artifactId)/promote",
            method: "POST",
            body: request
        )
    }

    func promoteBulk(repoKey: String, request: BulkPromotionRequest) async throws -> BulkPromotionResponse {
        try await self.request(
            "/api/v1/staging/repositories/\(repoKey)/promote-bulk",
            method: "POST",
            body: request
        )
    }

    func getPromotionHistory(repoKey: String) async throws -> [PromotionHistoryEntry] {
        let response: PromotionHistoryResponse = try await request(
            "/api/v1/staging/repositories/\(repoKey)/history?per_page=100"
        )
        return response.items
    }

    // MARK: - Virtual Repository Members

    func listVirtualMembers(repoKey: String) async throws -> [VirtualMember] {
        let response: VirtualMembersResponse = try await request(
            "/api/v1/repositories/\(repoKey)/members"
        )
        return response.items
    }

    func addVirtualMember(repoKey: String, memberKey: String, priority: Int?) async throws -> VirtualMember {
        try await request(
            "/api/v1/repositories/\(repoKey)/members",
            method: "POST",
            body: AddMemberRequest(memberKey: memberKey, priority: priority)
        )
    }

    func removeVirtualMember(repoKey: String, memberKey: String) async throws {
        try await requestVoid(
            "/api/v1/repositories/\(repoKey)/members/\(memberKey)",
            method: "DELETE"
        )
    }

    func reorderVirtualMembers(repoKey: String, members: [MemberPriority]) async throws {
        try await requestVoid(
            "/api/v1/repositories/\(repoKey)/members",
            method: "PUT",
            body: ReorderMembersRequest(members: members)
        )
    }

    // MARK: - Repositories

    func listRepositories() async throws -> [Repository] {
        let response: RepositoryListResponse = try await request("/api/v1/repositories?per_page=100")
        return response.items
    }

    func createRepository(request: CreateRepositoryRequest) async throws -> Repository {
        try await self.request(
            "/api/v1/repositories",
            method: "POST",
            body: request
        )
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

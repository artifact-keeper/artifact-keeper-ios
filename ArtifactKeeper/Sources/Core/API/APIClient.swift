import Foundation
import ArtifactKeeperClient
import OpenAPIRuntime
import OpenAPIURLSession

actor APIClient {
    static let shared = APIClient()

    static let serverURLKey = "serverURL"
    static let defaultServerURL = ""

    private var baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let sdkClient = SDKClient.shared

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
        Task { await sdkClient.setToken(token) }
    }

    func updateBaseURL(_ url: String) {
        self.baseURL = url
        UserDefaults.standard.set(url, forKey: APIClient.serverURLKey)
        Task { await sdkClient.updateBaseURL(url) }
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

    /// Generic request method kept for backward compatibility with views that call it directly.
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

    // MARK: - SDK-backed Methods

    // MARK: TOTP

    func totpSetup() async throws -> TotpSetupResponse {
        let client = await sdkClient.client
        let response = try await client.setup_totp()
        let data = try response.ok.body.json
        return TotpSetupResponse(secret: data.secret, qrCodeUrl: data.qr_code_url)
    }

    func totpEnable(code: String) async throws -> TotpEnableResponse {
        let client = await sdkClient.client
        let response = try await client.enable_totp(
            body: .json(.init(code: code))
        )
        let data = try response.ok.body.json
        return TotpEnableResponse(backupCodes: data.backup_codes)
    }

    func totpVerify(totpToken: String, code: String) async throws -> LoginResponse {
        let client = await sdkClient.client
        let response = try await client.verify_totp(
            body: .json(.init(code: code, totp_token: totpToken))
        )
        let data = try response.ok.body.json
        return LoginResponse(
            accessToken: data.access_token,
            refreshToken: data.refresh_token,
            expiresIn: Int(data.expires_in),
            tokenType: data.token_type,
            mustChangePassword: data.must_change_password,
            totpRequired: data.totp_required,
            totpToken: data.totp_token
        )
    }

    func totpDisable(password: String, code: String) async throws {
        let client = await sdkClient.client
        let response = try await client.disable_totp(
            body: .json(.init(code: code, password: password))
        )
        switch response {
        case .ok:
            return
        case .unauthorized(let err):
            let msg = (try? err.body.json.message) ?? "Unauthorized"
            throw APIError.httpError(statusCode: 401, data: msg.data(using: .utf8) ?? Data())
        case .undocumented(let statusCode, _):
            throw APIError.httpError(statusCode: statusCode, data: Data())
        }
    }

    // MARK: Password

    func changeUserPassword(userId: String, currentPassword: String, newPassword: String) async throws {
        let client = await sdkClient.client
        let response = try await client.change_password(
            path: .init(id: userId),
            body: .json(.init(current_password: currentPassword, new_password: newPassword))
        )
        // Use the .ok computed property -- it throws if the response is not .ok
        _ = try response.ok
    }

    // MARK: Profile

    func getProfile() async throws -> ProfileResponse {
        let client = await sdkClient.client
        let response = try await client.get_current_user()
        let data = try response.ok.body.json
        return ProfileResponse(
            id: data.id,
            username: data.username,
            email: data.email,
            displayName: data.display_name,
            isAdmin: data.is_admin,
            totpEnabled: data.totp_enabled
        )
    }

    func updateProfile(displayName: String?, email: String?) async throws -> ProfileResponse {
        // The SDK does not have a /profile endpoint, use raw request
        try await request(
            "/api/v1/profile",
            method: "PUT",
            body: UpdateProfileRequest(displayName: displayName, email: email)
        )
    }

    // MARK: API Keys (profile endpoints not in SDK, kept as raw requests)

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

    // MARK: Access Tokens (profile endpoints not in SDK, kept as raw requests)

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

    // MARK: Staging Repositories (staging endpoints not in SDK, kept as raw requests)

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

    // MARK: Virtual Repository Members

    func listVirtualMembers(repoKey: String) async throws -> [VirtualMember] {
        let client = await sdkClient.client
        let response = try await client.list_virtual_members(
            path: .init(key: repoKey)
        )
        let data = try response.ok.body.json
        return data.items.map { m in
            VirtualMember(
                id: m.id,
                memberRepoId: m.member_repo_id,
                memberRepoKey: m.member_repo_key,
                memberRepoName: m.member_repo_name,
                memberRepoType: m.member_repo_type,
                priority: Int(m.priority),
                createdAt: Self.formatDate(m.created_at)
            )
        }
    }

    func addVirtualMember(repoKey: String, memberKey: String, priority: Int?) async throws -> VirtualMember {
        let client = await sdkClient.client
        let response = try await client.add_virtual_member(
            path: .init(key: repoKey),
            body: .json(.init(
                member_key: memberKey,
                priority: priority.map { Int32($0) }
            ))
        )
        let m = try response.ok.body.json
        return VirtualMember(
            id: m.id,
            memberRepoId: m.member_repo_id,
            memberRepoKey: m.member_repo_key,
            memberRepoName: m.member_repo_name,
            memberRepoType: m.member_repo_type,
            priority: Int(m.priority),
            createdAt: Self.formatDate(m.created_at)
        )
    }

    func removeVirtualMember(repoKey: String, memberKey: String) async throws {
        let client = await sdkClient.client
        let response = try await client.remove_virtual_member(
            path: .init(key: repoKey, member_key: memberKey)
        )
        _ = try response.ok
    }

    func reorderVirtualMembers(repoKey: String, members: [MemberPriority]) async throws {
        let client = await sdkClient.client
        let response = try await client.update_virtual_members(
            path: .init(key: repoKey),
            body: .json(.init(
                members: members.map { m in
                    Components.Schemas.VirtualMemberPriority(
                        member_key: m.memberKey,
                        priority: Int32(m.priority)
                    )
                }
            ))
        )
        _ = try response.ok
    }

    // MARK: Repositories

    func listRepositories() async throws -> [Repository] {
        let client = await sdkClient.client
        let response = try await client.list_repositories(
            query: .init(per_page: 100)
        )
        let data = try response.ok.body.json
        return data.items.map { Repository(from: $0) }
    }

    func createRepository(request: CreateRepositoryRequest) async throws -> Repository {
        let client = await sdkClient.client
        let response = try await client.create_repository(
            body: .json(.init(
                description: request.description,
                format: request.format,
                is_public: request.isPublic,
                key: request.key,
                name: request.name,
                repo_type: request.repoType,
                upstream_url: request.upstreamUrl
            ))
        )
        let data = try response.ok.body.json
        return Repository(from: data)
    }

    // MARK: Artifact Upload (multipart -- kept as raw URLSession)

    func uploadArtifact(repoKey: String, fileURL: URL, customPath: String?) async throws -> Artifact {
        let boundary = UUID().uuidString
        guard let url = URL(string: "\(baseURL)/api/v1/repositories/\(repoKey)/artifacts") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent

        var body = Data()
        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Custom path part
        if let path = customPath, !path.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
            body.append(path.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        return try decoder.decode(Artifact.self, from: data)
    }

    // MARK: Repository Security Config

    func getRepoSecurityConfig(repoKey: String) async throws -> RepoSecurityConfig {
        let response: RepoSecurityInfoResponse = try await request(
            "/api/v1/repositories/\(repoKey)/security"
        )
        return response.config ?? RepoSecurityConfig(
            scanEnabled: false,
            scanOnUpload: false,
            scanOnProxy: false,
            blockOnPolicyViolation: false,
            severityThreshold: "high"
        )
    }

    func updateRepoSecurityConfig(repoKey: String, config: RepoSecurityConfig) async throws -> RepoSecurityConfig {
        try await request(
            "/api/v1/repositories/\(repoKey)/security",
            method: "PUT",
            body: config
        )
    }

    // MARK: - Date Formatting Helper

    nonisolated static func formatDate(_ date: Foundation.Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}

// MARK: - Repository Conversion Extension

extension Repository {
    init(from sdk: Components.Schemas.RepositoryResponse) {
        self.init(
            id: sdk.id,
            key: sdk.key,
            name: sdk.name,
            format: sdk.format,
            repoType: sdk.repo_type,
            isPublic: sdk.is_public,
            description: sdk.description,
            storageUsedBytes: sdk.storage_used_bytes,
            quotaBytes: sdk.quota_bytes,
            createdAt: APIClient.formatDate(sdk.created_at),
            updatedAt: APIClient.formatDate(sdk.updated_at)
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

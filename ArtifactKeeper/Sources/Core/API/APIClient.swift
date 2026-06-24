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

    /// Callback invoked on the main actor when a 401 could not be recovered
    /// via token refresh. The UI layer sets this to trigger re-authentication.
    var onAuthFailure: (@MainActor @Sendable () -> Void)?

    /// Callback that attempts a token refresh. Returns `true` if new tokens
    /// were obtained and the failed request should be retried.
    var onTokenRefresh: (@Sendable () async -> Bool)?

    /// Guards against multiple concurrent refresh attempts.
    private var isRefreshing = false

    init() {
        let stored = UserDefaults.standard.string(forKey: APIClient.serverURLKey)
        self.baseURL = stored ?? APIClient.defaultServerURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config, delegate: SelfSignedCertDelegate(), delegateQueue: nil)
        self.decoder = JSONDecoder()
    }

    /// Testing initializer that accepts a custom URLSession (e.g. with a stubbed URLProtocol).
    init(baseURL: String, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Test-only override for the generated SDK client. When set, SDK-backed methods use
    /// this client instead of the shared one, so a mock transport can assert the request
    /// path and method (operation dispatch) without hitting the network.
    private var injectedSDKClient: ArtifactKeeperClient.Client?

    /// Inject a generated SDK client for tests. Production code never calls this.
    func setSDKClientForTesting(_ client: ArtifactKeeperClient.Client) {
        self.injectedSDKClient = client
    }

    /// The SDK client SDK-backed methods should use: the injected one in tests, otherwise
    /// the shared client.
    private func sdkClientInstance() async -> ArtifactKeeperClient.Client {
        if let injectedSDKClient { return injectedSDKClient }
        return await sdkClient.client
    }

    func setToken(_ token: String?) {
        self.accessToken = token
        Task { await sdkClient.setToken(token) }
    }

    func setTokenRefreshHandler(_ handler: @escaping @Sendable () async -> Bool) {
        self.onTokenRefresh = handler
    }

    func setAuthFailureHandler(_ handler: @escaping @MainActor @Sendable () -> Void) {
        self.onAuthFailure = handler
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

    // MARK: - Request Methods with 401 Retry

    /// Generic request method kept for backward compatibility with views that call it directly.
    /// Automatically retries once on a 401 after attempting a token refresh.
    func request<T: Decodable & Sendable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        let encodedBody: Data?
        if let body {
            encodedBody = try JSONEncoder().encode(body)
        } else {
            encodedBody = nil
        }

        let (data, httpResponse) = try await executeRequest(url: url, method: method, body: encodedBody)

        if httpResponse.statusCode == 401 {
            if let (retryData, retryResponse) = try? await attemptRefreshAndRetry(
                url: url, method: method, body: encodedBody
            ) {
                guard (200...299).contains(retryResponse.statusCode) else {
                    throw APIError.httpError(statusCode: retryResponse.statusCode, data: retryData)
                }
                return try decoder.decode(T.self, from: retryData)
            }
            if let onAuthFailure {
                await onAuthFailure()
            }
            throw APIError.httpError(statusCode: 401, data: data)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return try decoder.decode(T.self, from: data)
    }

    /// Fire a request where the response body is empty or can be ignored.
    /// Automatically retries once on a 401 after attempting a token refresh.
    func requestVoid(
        _ endpoint: String,
        method: String = "POST",
        body: (any Encodable)? = nil
    ) async throws {
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        let encodedBody: Data?
        if let body {
            encodedBody = try JSONEncoder().encode(body)
        } else {
            encodedBody = nil
        }

        let (data, httpResponse) = try await executeRequest(url: url, method: method, body: encodedBody)

        if httpResponse.statusCode == 401 {
            if let (retryData, retryResponse) = try? await attemptRefreshAndRetry(
                url: url, method: method, body: encodedBody
            ) {
                guard (200...299).contains(retryResponse.statusCode) else {
                    throw APIError.httpError(statusCode: retryResponse.statusCode, data: retryData)
                }
                return
            }
            if let onAuthFailure {
                await onAuthFailure()
            }
            throw APIError.httpError(statusCode: 401, data: data)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Internal Request Helpers

    /// Execute a single HTTP request and return the raw data and response.
    private func executeRequest(
        url: URL,
        method: String,
        body: Data?
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        return (data, httpResponse)
    }

    /// Attempt a token refresh, then retry the original request.
    /// Returns `nil` if no refresh callback is configured or refresh failed.
    private func attemptRefreshAndRetry(
        url: URL,
        method: String,
        body: Data?
    ) async throws -> (Data, HTTPURLResponse)? {
        guard let onTokenRefresh, !isRefreshing else { return nil }

        isRefreshing = true
        let refreshed = await onTokenRefresh()
        isRefreshing = false

        guard refreshed else { return nil }

        return try await executeRequest(url: url, method: method, body: body)
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

    // MARK: API Tokens (unified 1.2.1 surface)
    //
    // 1.2.1 removed /api/v1/profile/api-keys and /profile/access-tokens in favor of a
    // single token API. Listing is per user (/api/v1/users/{id}/tokens), create is
    // /api/v1/auth/tokens, delete is /api/v1/auth/tokens/{token_id}. The two Profile
    // tabs (API keys, access tokens) both map onto this one surface; responses are
    // adapted back to the existing ApiKey/AccessToken view types.

    /// Resolve the current user's id via /api/v1/auth/me. Required because token
    /// listing is scoped to a user id in 1.2.1.
    private func currentUserId() async throws -> String {
        let me: ProfileResponse = try await request("/api/v1/auth/me")
        return me.id
    }

    func listApiKeys() async throws -> [ApiKey] {
        let userId = try await currentUserId()
        let response: ApiTokenListResponse = try await request("/api/v1/users/\(userId)/tokens")
        return response.items.map { token in
            ApiKey(
                id: token.id,
                name: token.name,
                keyPrefix: token.tokenPrefix,
                createdAt: token.createdAt,
                expiresAt: token.expiresAt,
                lastUsedAt: token.lastUsedAt,
                scopes: token.scopes
            )
        }
    }

    func createApiKey(name: String, scopes: [String], expiresInDays: Int?) async throws -> CreateApiKeyResponse {
        let created: ApiTokenCreatedResponse = try await request(
            "/api/v1/auth/tokens",
            method: "POST",
            body: CreateApiKeyRequest(name: name, expiresInDays: expiresInDays, scopes: scopes)
        )
        let apiKey = ApiKey(
            id: created.id,
            name: created.name,
            keyPrefix: String(created.token.prefix(8)),
            createdAt: "",
            expiresAt: nil,
            lastUsedAt: nil,
            scopes: scopes
        )
        return CreateApiKeyResponse(apiKey: apiKey, key: created.token)
    }

    func deleteApiKey(_ id: String) async throws {
        try await requestVoid("/api/v1/auth/tokens/\(id)", method: "DELETE")
    }

    func listAccessTokens() async throws -> [AccessToken] {
        let userId = try await currentUserId()
        let response: ApiTokenListResponse = try await request("/api/v1/users/\(userId)/tokens")
        return response.items.map { token in
            AccessToken(
                id: token.id,
                name: token.name,
                tokenPrefix: token.tokenPrefix,
                createdAt: token.createdAt,
                expiresAt: token.expiresAt,
                lastUsedAt: token.lastUsedAt,
                scopes: token.scopes
            )
        }
    }

    func createAccessToken(name: String, scopes: [String], expiresInDays: Int?) async throws -> CreateAccessTokenResponse {
        let created: ApiTokenCreatedResponse = try await request(
            "/api/v1/auth/tokens",
            method: "POST",
            body: CreateAccessTokenRequest(name: name, expiresInDays: expiresInDays, scopes: scopes)
        )
        let accessToken = AccessToken(
            id: created.id,
            name: created.name,
            tokenPrefix: String(created.token.prefix(8)),
            createdAt: "",
            expiresAt: nil,
            lastUsedAt: nil,
            scopes: scopes
        )
        return CreateAccessTokenResponse(accessToken: accessToken, token: created.token)
    }

    func deleteAccessToken(_ id: String) async throws {
        try await requestVoid("/api/v1/auth/tokens/\(id)", method: "DELETE")
    }

    // MARK: Staging Repositories (staging endpoints not in SDK, kept as raw requests)

    // TODO(#42): The whole staging/promotion cluster is deferred to the Staging section
    // wave. 1.2.1 changed it in two ways that a regression path swap cannot cover:
    //   1. The /api/v1/staging endpoints were removed. There is no replacement
    //      "list staging repositories" or "list staging artifacts" operation, so
    //      listStagingRepos/listStagingArtifacts need a screen redesign over
    //      list_repositories (filtered by type) and list_artifacts.
    //   2. Promotion moved to /api/v1/promotion/repositories/... AND the request and
    //      response bodies changed shape (PromoteArtifactRequest/PromotionResponse/
    //      BulkPromoteRequest/PromotionHistoryResponse), so promote/bulk/history need
    //      real model migration, not just a new path.
    // These call sites are intentionally left on the removed /api/v1/staging paths until
    // that migration lands in #42; a path-only swap would send the wrong bodies.

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
        // TODO(#42): move to /api/v1/promotion/.../promote with PromoteArtifactRequest body.
        try await self.request(
            "/api/v1/staging/repositories/\(repoKey)/artifacts/\(artifactId)/promote",
            method: "POST",
            body: request
        )
    }

    func promoteBulk(repoKey: String, request: BulkPromotionRequest) async throws -> BulkPromotionResponse {
        // TODO(#42): move to /api/v1/promotion/.../promote with BulkPromoteRequest body.
        try await self.request(
            "/api/v1/staging/repositories/\(repoKey)/promote-bulk",
            method: "POST",
            body: request
        )
    }

    func getPromotionHistory(repoKey: String) async throws -> [PromotionHistoryEntry] {
        // TODO(#42): move to /api/v1/promotion/.../promotion-history with the new response shape.
        let response: PromotionHistoryResponse = try await request(
            "/api/v1/staging/repositories/\(repoKey)/history?per_page=100"
        )
        return response.items
    }

    // MARK: Artifact Detail (1.2.1: /api/v1/artifacts/{id} + /metadata, /stats, /labels)

    func getArtifactDetail(id: String) async throws -> ArtifactDetail {
        try await request("/api/v1/artifacts/\(id)")
    }

    func getArtifactMetadata(id: String) async throws -> ArtifactMetadata {
        try await request("/api/v1/artifacts/\(id)/metadata")
    }

    func getArtifactStats(id: String) async throws -> ArtifactStats {
        try await request("/api/v1/artifacts/\(id)/stats")
    }

    func listArtifactLabels(id: String) async throws -> [ArtifactLabel] {
        let response: ArtifactLabelsListResponse = try await request("/api/v1/artifacts/\(id)/labels")
        return response.items
    }

    /// Replace the full label set on an artifact.
    func setArtifactLabels(id: String, labels: [ArtifactLabelEntry]) async throws -> [ArtifactLabel] {
        let response: ArtifactLabelsListResponse = try await request(
            "/api/v1/artifacts/\(id)/labels",
            method: "PUT",
            body: SetArtifactLabelsRequest(labels: labels)
        )
        return response.items
    }

    /// Add or update a single label by key.
    func addArtifactLabel(id: String, key: String, value: String?) async throws -> ArtifactLabel {
        try await request(
            "/api/v1/artifacts/\(id)/labels/\(key)",
            method: "POST",
            body: AddArtifactLabelRequest(value: value)
        )
    }

    func deleteArtifactLabel(id: String, key: String) async throws {
        try await requestVoid("/api/v1/artifacts/\(id)/labels/\(key)", method: "DELETE")
    }

    // MARK: Plugins (Integration: GET /api/v1/plugins/{id})

    /// Fetch a single plugin's current state by id.
    func getPlugin(id: String) async throws -> Plugin {
        try await request("/api/v1/plugins/\(id)")
    }

    // MARK: Repository Tree Browse (1.2.1: GET /api/v1/tree)

    /// Fetch the repository tree at a given path. Pass an empty path for the root.
    /// Raw file content (GET /api/v1/tree/content) is octet-stream and deferred to
    /// a download/preview flow; this returns the directory/file node listing only.
    func getRepositoryTree(repoKey: String, path: String = "") async throws -> [TreeNode] {
        var components = "repository_key=\(Self.queryEncoded(repoKey))"
        if !path.isEmpty {
            components += "&path=\(Self.queryEncoded(path))"
        }
        let response: TreeResponse = try await request("/api/v1/tree?\(components)")
        return response.nodes
    }

    // MARK: Package Versions (1.2.1: GET /api/v1/packages/{id}/versions)

    func getPackageVersions(packageId: String) async throws -> [PackageVersion] {
        let response: PackageVersionsResponse = try await request("/api/v1/packages/\(packageId)/versions")
        return response.versions
    }

    private static func queryEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    // MARK: Virtual Repository Members

    func listVirtualMembers(repoKey: String) async throws -> [VirtualMember] {
        let client = await sdkClient.client
        let response = try await client.list_virtual_members(
            path: .init(key: repoKey)
        )
        let data = try response.ok.body.json
        return data.members.map { m in
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

    func updateRepository(key: String, request: UpdateRepositoryRequest) async throws -> Repository {
        try await self.request("/api/v1/repositories/\(key)", method: "PATCH", body: request)
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

    // MARK: Security Scans & Findings (SDK-backed)

    /// List scans for a single artifact (GET /api/v1/security/artifacts/{artifact_id}/scans).
    func listArtifactScans(artifactId: String) async throws -> [ScanResult] {
        let client = await sdkClientInstance()
        let response = try await client.list_artifact_scans(
            path: .init(artifact_id: artifactId),
            query: .init(per_page: 200)
        )
        let data = try response.ok.body.json
        return data.items.map { ScanResult(from: $0) }
    }

    /// List findings for a scan (GET /api/v1/security/scans/{id}/findings).
    func listFindings(scanId: String) async throws -> [ScanFinding] {
        let client = await sdkClientInstance()
        let response = try await client.list_findings(
            path: .init(id: scanId),
            query: .init(per_page: 200)
        )
        let data = try response.ok.body.json
        return data.items.map { ScanFinding(from: $0) }
    }

    /// List scans for a single repository (GET /api/v1/repositories/{key}/security/scans).
    func listRepoScans(repoKey: String) async throws -> [ScanResult] {
        let client = await sdkClientInstance()
        let response = try await client.list_repo_scans(
            path: .init(key: repoKey),
            query: .init(per_page: 100)
        )
        let data = try response.ok.body.json
        return data.items.map { ScanResult(from: $0) }
    }

    /// Security overview counts (GET /api/v1/security/dashboard).
    func getSecurityDashboard() async throws -> SecurityDashboard {
        let client = await sdkClientInstance()
        let response = try await client.get_dashboard()
        let data = try response.ok.body.json
        return SecurityDashboard(from: data)
    }

    /// Per-repository security scores (GET /api/v1/security/scores).
    func getSecurityScores() async throws -> [RepoSecurityScore] {
        let client = await sdkClientInstance()
        let response = try await client.get_all_scores()
        let data = try response.ok.body.json
        return data.map { RepoSecurityScore(from: $0) }
    }

    /// Acknowledge a finding with a reason (POST /api/v1/security/findings/{id}/acknowledge).
    /// Returns the updated finding.
    func acknowledgeFinding(id: String, reason: String) async throws -> ScanFinding {
        let client = await sdkClientInstance()
        let response = try await client.acknowledge_finding(
            path: .init(id: id),
            body: .json(.init(reason: reason))
        )
        let data = try response.ok.body.json
        return ScanFinding(from: data)
    }

    /// Revoke a finding's acknowledgment (DELETE /api/v1/security/findings/{id}/acknowledge).
    /// Returns the updated finding.
    func revokeFindingAcknowledgment(id: String) async throws -> ScanFinding {
        let client = await sdkClientInstance()
        let response = try await client.revoke_acknowledgment(path: .init(id: id))
        let data = try response.ok.body.json
        return ScanFinding(from: data)
    }

    /// Trigger a scan for an artifact or repository (POST /api/v1/security/scan).
    func triggerScan(artifactId: String? = nil, repositoryId: String? = nil) async throws -> TriggerScanResult {
        let client = await sdkClientInstance()
        let response = try await client.trigger_scan(
            body: .json(.init(artifact_id: artifactId, repository_id: repositoryId))
        )
        let data = try response.ok.body.json
        return TriggerScanResult(from: data)
    }

    /// List per-repository scan configurations (GET /api/v1/security/configs).
    func listScanConfigs() async throws -> [ScanConfig] {
        let client = await sdkClientInstance()
        let response = try await client.list_scan_configs()
        let data = try response.ok.body.json
        return data.map { ScanConfig(from: $0) }
    }

    // MARK: Quality Gates & Health (SDK-backed)

    /// List quality gate definitions (GET /api/v1/quality/gates).
    func listQualityGates() async throws -> [QualityGate] {
        let client = await sdkClientInstance()
        let response = try await client.list_gates()
        let data = try response.ok.body.json
        return data.map { QualityGate(from: $0) }
    }

    /// Fetch a single quality gate (GET /api/v1/quality/gates/{id}).
    func getQualityGate(id: String) async throws -> QualityGate {
        let client = await sdkClientInstance()
        let response = try await client.get_gate(path: .init(id: id))
        let data = try response.ok.body.json
        return QualityGate(from: data)
    }

    /// Evaluate gates against an artifact (POST /api/v1/quality/gates/evaluate/{artifact_id}).
    func evaluateGate(artifactId: String, repositoryId: String? = nil) async throws -> GateEvaluation {
        let client = await sdkClientInstance()
        let response = try await client.evaluate_gate(
            path: .init(artifact_id: artifactId),
            query: .init(repository_id: repositoryId)
        )
        let data = try response.ok.body.json
        return GateEvaluation(from: data)
    }

    /// Fetch the quality health dashboard (GET /api/v1/quality/health/dashboard).
    func getHealthDashboard() async throws -> HealthDashboard {
        let client = await sdkClientInstance()
        let response = try await client.get_health_dashboard()
        let data = try response.ok.body.json
        return HealthDashboard(from: data)
    }

    /// Health for a single repository (GET /api/v1/quality/health/repositories/{key}).
    func getRepoHealth(repoKey: String) async throws -> RepoHealth {
        let client = await sdkClientInstance()
        let response = try await client.get_repo_health(path: .init(key: repoKey))
        let data = try response.ok.body.json
        return RepoHealth(from: data)
    }

    /// Health for a single artifact (GET /api/v1/quality/health/artifacts/{artifact_id}).
    func getArtifactHealth(artifactId: String) async throws -> ArtifactHealth {
        let client = await sdkClientInstance()
        let response = try await client.get_artifact_health(path: .init(artifact_id: artifactId))
        let data = try response.ok.body.json
        return ArtifactHealth(from: data)
    }

    // MARK: SBOM (SDK-backed)

    /// Fetch the SBOM summary for an artifact (GET /api/v1/sbom/by-artifact/{artifact_id}).
    func getSbomByArtifact(artifactId: String) async throws -> SbomSummary {
        let client = await sdkClientInstance()
        let response = try await client.get_sbom_by_artifact(
            path: .init(artifact_id: artifactId)
        )
        let data = try response.ok.body.json
        return SbomSummary(from: data)
    }

    /// List the components in a SBOM (GET /api/v1/sbom/{id}/components).
    func getSbomComponents(sbomId: String) async throws -> [SbomComponent] {
        let client = await sdkClientInstance()
        let response = try await client.get_sbom_components(path: .init(id: sbomId))
        let data = try response.ok.body.json
        return data.map { SbomComponent(from: $0) }
    }

    // MARK: CVE History & License Compliance (raw requests, matching SbomView)

    /// CVE history for a single artifact (GET /api/v1/sbom/cve/history/by-artifact/{artifact_id}).
    func getCveHistoryByArtifact(artifactId: String) async throws -> [CveHistoryEntry] {
        let encoded = artifactId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artifactId
        return try await request("/api/v1/sbom/cve/history/by-artifact/\(encoded)")
    }

    /// History of a specific CVE across artifacts (GET /api/v1/sbom/cve/history/by-cve/{cve_id}).
    func getCveHistoryByCve(cveId: String) async throws -> [CveHistoryEntry] {
        let encoded = cveId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cveId
        return try await request("/api/v1/sbom/cve/history/by-cve/\(encoded)")
    }

    /// A single CVE history record by id (GET /api/v1/sbom/cve/history/{id}).
    func getCveHistory(id: String) async throws -> CveHistoryEntry {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await request("/api/v1/sbom/cve/history/\(encoded)")
    }

    /// Check a set of licenses against policy (POST /api/v1/sbom/check-compliance).
    func checkLicenseCompliance(licenses: [String], repositoryId: String? = nil) async throws -> LicenseCheckResult {
        let body = CheckLicenseComplianceRequest(licenses: licenses, repositoryId: repositoryId)
        return try await request("/api/v1/sbom/check-compliance", method: "POST", body: body)
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

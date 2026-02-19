import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - Auth Models

@Suite("Auth Model Tests")
struct AuthModelTests {

    @Test func loginRequestEncodesCorrectly() throws {
        let request = LoginRequest(username: "testuser", password: "test-value-not-real") // NOSONAR: test fixture
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["username"] as? String == "testuser")
        #expect(json?["password"] as? String == "test-value-not-real")
    }

    @Test func loginResponseDecodesFromSnakeCase() throws {
        let json = """
        {
            "access_token": "eyJhbGciOiJIUzI1NiJ9.test.sig",
            "refresh_token": "refresh_abc",
            "expires_in": 3600,
            "token_type": "Bearer",
            "must_change_password": false,
            "totp_required": null,
            "totp_token": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LoginResponse.self, from: json)
        #expect(response.accessToken == "eyJhbGciOiJIUzI1NiJ9.test.sig")
        #expect(response.refreshToken == "refresh_abc")
        #expect(response.expiresIn == 3600)
        #expect(response.tokenType == "Bearer")
        #expect(response.mustChangePassword == false)
        #expect(response.totpRequired == nil)
        #expect(response.totpToken == nil)
    }

    @Test func loginResponseRoundTrip() throws {
        let original = LoginResponse(
            accessToken: "tok_123",
            refreshToken: "ref_456",
            expiresIn: 7200,
            tokenType: "Bearer",
            mustChangePassword: true,
            totpRequired: true,
            totpToken: "totp_789"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        #expect(decoded.accessToken == original.accessToken)
        #expect(decoded.refreshToken == original.refreshToken)
        #expect(decoded.expiresIn == original.expiresIn)
        #expect(decoded.tokenType == original.tokenType)
        #expect(decoded.mustChangePassword == original.mustChangePassword)
        #expect(decoded.totpRequired == original.totpRequired)
        #expect(decoded.totpToken == original.totpToken)
    }

    @Test func loginResponseWithNilOptionals() throws {
        let json = """
        {
            "access_token": "tok",
            "refresh_token": "ref",
            "expires_in": 60,
            "token_type": "Bearer"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LoginResponse.self, from: json)
        #expect(response.mustChangePassword == nil)
        #expect(response.totpRequired == nil)
        #expect(response.totpToken == nil)
    }

    @Test func userInfoDecodesFromServerJSON() throws {
        let json = """
        {
            "sub": "user-uuid-123",
            "username": "jdoe",
            "email": "jdoe@example.com",
            "is_admin": true,
            "totp_enabled": false
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(UserInfo.self, from: json)
        #expect(user.id == "user-uuid-123")
        #expect(user.username == "jdoe")
        #expect(user.email == "jdoe@example.com")
        #expect(user.isAdmin == true)
        #expect(user.totpEnabled == false)
    }

    @Test func userInfoDefaultsTotpEnabledToFalse() throws {
        let json = """
        {
            "sub": "id-1",
            "username": "alice",
            "is_admin": false
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(UserInfo.self, from: json)
        #expect(user.totpEnabled == false)
        #expect(user.email == nil)
    }

    @Test func userInfoIsIdentifiable() throws {
        let json = """
        {"sub": "abc", "username": "u", "is_admin": false}
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(UserInfo.self, from: json)
        #expect(user.id == "abc")
    }

    @Test func setupStatusResponseDecodes() throws {
        let json = """
        {"setup_required": true}
        """.data(using: .utf8)!
        let status = try JSONDecoder().decode(SetupStatusResponse.self, from: json)
        #expect(status.setupRequired == true)
    }

    @Test func totpSetupResponseRoundTrip() throws {
        let original = TotpSetupResponse(secret: "AAAAAABBBBBBCCCCCC", qrCodeUrl: "otpauth://totp/test") // NOSONAR: test fixture
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TotpSetupResponse.self, from: data)
        #expect(decoded.secret == original.secret)
        #expect(decoded.qrCodeUrl == original.qrCodeUrl)
    }

    @Test func totpEnableResponseRoundTrip() throws {
        let original = TotpEnableResponse(backupCodes: ["code1", "code2", "code3"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TotpEnableResponse.self, from: data)
        #expect(decoded.backupCodes == original.backupCodes)
    }

    @Test func totpEnableResponseEmptyBackupCodes() throws {
        let original = TotpEnableResponse(backupCodes: [])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TotpEnableResponse.self, from: data)
        #expect(decoded.backupCodes.isEmpty)
    }

    @Test func totpCodeRequestEncodes() throws {
        let req = TotpCodeRequest(code: "123456")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["code"] as? String == "123456")
    }

    @Test func totpVerifyRequestEncodesSnakeCase() throws {
        let req = TotpVerifyRequest(totpToken: "token_abc", code: "654321")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["totp_token"] as? String == "token_abc")
        #expect(json?["code"] as? String == "654321")
    }

    @Test func totpDisableRequestEncodes() throws {
        let req = TotpDisableRequest(password: "test-value-not-real", code: "111111") // NOSONAR: test fixture
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["password"] as? String == "test-value-not-real")
        #expect(json?["code"] as? String == "111111")
    }

    @Test func changePasswordRequestEncodesSnakeCase() throws {
        let req = ChangePasswordRequest(currentPassword: "test-old-value", newPassword: "test-new-value") // NOSONAR: test fixture
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["current_password"] as? String == "test-old-value")
        #expect(json?["new_password"] as? String == "test-new-value")
    }

    @Test func profileResponseRoundTrip() throws {
        let original = ProfileResponse(
            id: "prof-1",
            username: "admin",
            email: "admin@test.com",
            displayName: "Admin User",
            isAdmin: true,
            totpEnabled: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileResponse.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.username == original.username)
        #expect(decoded.email == original.email)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.isAdmin == original.isAdmin)
        #expect(decoded.totpEnabled == original.totpEnabled)
    }

    @Test func profileResponseNilDisplayName() throws {
        let original = ProfileResponse(
            id: "p-2",
            username: "user",
            email: "user@test.com",
            displayName: nil,
            isAdmin: false,
            totpEnabled: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileResponse.self, from: data)
        #expect(decoded.displayName == nil)
    }

    @Test func updateProfileRequestEncodesSnakeCase() throws {
        let req = UpdateProfileRequest(displayName: "New Name", email: "new@test.com")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["display_name"] as? String == "New Name")
        #expect(json?["email"] as? String == "new@test.com")
    }

    @Test func apiKeyDecodesFromJSON() throws {
        let json = """
        {
            "id": "key-1",
            "name": "CI Key",
            "key_prefix": "ak_",
            "created_at": "2024-01-01T00:00:00Z",
            "expires_at": "2025-01-01T00:00:00Z",
            "last_used_at": null,
            "scopes": ["read", "write"]
        }
        """.data(using: .utf8)!

        let key = try JSONDecoder().decode(ApiKey.self, from: json)
        #expect(key.id == "key-1")
        #expect(key.name == "CI Key")
        #expect(key.keyPrefix == "ak_")
        #expect(key.expiresAt == "2025-01-01T00:00:00Z")
        #expect(key.lastUsedAt == nil)
        #expect(key.scopes == ["read", "write"])
    }

    @Test func apiKeysListResponseDecodes() throws {
        let json = """
        {
            "api_keys": [
                {
                    "id": "k1",
                    "name": "Key 1",
                    "key_prefix": "ak_",
                    "created_at": "2024-01-01T00:00:00Z",
                    "expires_at": null,
                    "last_used_at": null,
                    "scopes": []
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ApiKeysListResponse.self, from: json)
        #expect(response.apiKeys.count == 1)
        #expect(response.apiKeys[0].name == "Key 1")
    }

    @Test func createApiKeyRequestEncodesSnakeCase() throws {
        let req = CreateApiKeyRequest(name: "Test", expiresInDays: 30, scopes: ["read"])
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["name"] as? String == "Test")
        #expect(json?["expires_in_days"] as? Int == 30)
        #expect(json?["scopes"] as? [String] == ["read"])
    }

    @Test func accessTokenDecodesFromJSON() throws {
        let json = """
        {
            "id": "tok-1",
            "name": "Deploy Token",
            "token_prefix": "at_",
            "created_at": "2024-06-01T00:00:00Z",
            "expires_at": null,
            "last_used_at": "2024-06-15T12:00:00Z",
            "scopes": ["read"]
        }
        """.data(using: .utf8)!

        let token = try JSONDecoder().decode(AccessToken.self, from: json)
        #expect(token.id == "tok-1")
        #expect(token.name == "Deploy Token")
        #expect(token.tokenPrefix == "at_")
        #expect(token.expiresAt == nil)
        #expect(token.lastUsedAt == "2024-06-15T12:00:00Z")
    }

    @Test func accessTokensListResponseDecodes() throws {
        let json = """
        {"access_tokens": []}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AccessTokensListResponse.self, from: json)
        #expect(response.accessTokens.isEmpty)
    }
}

// MARK: - Repository Models

@Suite("Repository Model Tests")
struct RepositoryModelTests {

    @Test func repositoryDecodesFromJSON() throws {
        let json = """
        {
            "id": "repo-1",
            "key": "maven-central",
            "name": "Maven Central Proxy",
            "format": "maven",
            "repo_type": "proxy",
            "is_public": true,
            "description": "Central Maven repository proxy",
            "storage_used_bytes": 1048576,
            "quota_bytes": 10737418240,
            "created_at": "2024-01-15T10:30:00Z",
            "updated_at": "2024-06-20T14:00:00Z"
        }
        """.data(using: .utf8)!

        let repo = try JSONDecoder().decode(Repository.self, from: json)
        #expect(repo.id == "repo-1")
        #expect(repo.key == "maven-central")
        #expect(repo.name == "Maven Central Proxy")
        #expect(repo.format == "maven")
        #expect(repo.repoType == "proxy")
        #expect(repo.isPublic == true)
        #expect(repo.description == "Central Maven repository proxy")
        #expect(repo.storageUsedBytes == 1048576)
        #expect(repo.quotaBytes == 10737418240)
    }

    @Test func repositoryRoundTrip() throws {
        let original = Repository(
            id: "r-1",
            key: "npm-local",
            name: "NPM Local",
            format: "npm",
            repoType: "local",
            isPublic: false,
            description: nil,
            storageUsedBytes: 0,
            quotaBytes: nil,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Repository.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.key == original.key)
        #expect(decoded.description == nil)
        #expect(decoded.quotaBytes == nil)
    }

    @Test func repositoryIsIdentifiable() throws {
        let repo = Repository(
            id: "test-id",
            key: "k",
            name: "n",
            format: "generic",
            repoType: "local",
            isPublic: false,
            description: nil,
            storageUsedBytes: 0,
            quotaBytes: nil,
            createdAt: "",
            updatedAt: ""
        )
        #expect(repo.id == "test-id")
    }

    @Test func paginationDecodesFromJSON() throws {
        let json = """
        {
            "page": 1,
            "per_page": 25,
            "total": 100,
            "total_pages": 4
        }
        """.data(using: .utf8)!

        let pagination = try JSONDecoder().decode(Pagination.self, from: json)
        #expect(pagination.page == 1)
        #expect(pagination.perPage == 25)
        #expect(pagination.total == 100)
        #expect(pagination.totalPages == 4)
    }

    @Test func paginationWithNilTotalPages() throws {
        let json = """
        {"page": 2, "per_page": 10, "total": 15}
        """.data(using: .utf8)!

        let pagination = try JSONDecoder().decode(Pagination.self, from: json)
        #expect(pagination.totalPages == nil)
    }

    @Test func repositoryListResponseDecodes() throws {
        let json = """
        {
            "items": [
                {
                    "id": "r1",
                    "key": "k1",
                    "name": "Repo 1",
                    "format": "docker",
                    "repo_type": "local",
                    "is_public": false,
                    "storage_used_bytes": 500,
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-01T00:00:00Z"
                }
            ],
            "pagination": {
                "page": 1,
                "per_page": 25,
                "total": 1
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RepositoryListResponse.self, from: json)
        #expect(response.items.count == 1)
        #expect(response.items[0].format == "docker")
        #expect(response.pagination?.page == 1)
    }

    @Test func repositoryListResponseEmptyItems() throws {
        let json = """
        {"items": [], "pagination": null}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RepositoryListResponse.self, from: json)
        #expect(response.items.isEmpty)
        #expect(response.pagination == nil)
    }

    @Test func createRepositoryRequestEncodesSnakeCase() throws {
        let req = CreateRepositoryRequest(
            key: "pypi-local",
            name: "PyPI Local",
            format: "pypi",
            repoType: "local",
            isPublic: true,
            description: "Local PyPI repo",
            upstreamUrl: nil
        )
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["key"] as? String == "pypi-local")
        #expect(json?["repo_type"] as? String == "local")
        #expect(json?["is_public"] as? Bool == true)
        #expect(json?["upstream_url"] == nil || json?["upstream_url"] is NSNull)
    }

    @Test func createRepositoryRequestDefaults() throws {
        let req = CreateRepositoryRequest(
            key: "k",
            name: "n",
            format: "generic",
            repoType: "local"
        )
        #expect(req.isPublic == false)
        #expect(req.description == nil)
        #expect(req.upstreamUrl == nil)
    }

    @Test func updateRepositoryRequestEncodesSnakeCase() throws {
        let req = UpdateRepositoryRequest(name: "New Name", isPublic: true)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["name"] as? String == "New Name")
        #expect(json?["is_public"] as? Bool == true)
        // key and description should be null
        #expect(json?["key"] is NSNull || json?["key"] == nil)
    }

    @Test func updateRepositoryRequestAllNil() throws {
        let req = UpdateRepositoryRequest()
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
        // All values should be null or absent
    }
}

// MARK: - Artifact Models

@Suite("Artifact Model Tests")
struct ArtifactModelTests {

    @Test func artifactDecodesFromJSON() throws {
        let json = """
        {
            "id": "art-1",
            "repository_key": "maven-local",
            "name": "my-library",
            "path": "com/example/my-library/1.0.0/my-library-1.0.0.jar",
            "version": "1.0.0",
            "content_type": "application/java-archive",
            "size_bytes": 204800,
            "download_count": 42,
            "checksum_sha256": "e3b0c44298fc1c149afbf4c8996fb924",
            "created_at": "2024-03-15T09:00:00Z"
        }
        """.data(using: .utf8)!

        let artifact = try JSONDecoder().decode(Artifact.self, from: json)
        #expect(artifact.id == "art-1")
        #expect(artifact.repositoryKey == "maven-local")
        #expect(artifact.name == "my-library")
        #expect(artifact.version == "1.0.0")
        #expect(artifact.contentType == "application/java-archive")
        #expect(artifact.sizeBytes == 204800)
        #expect(artifact.downloadCount == 42)
        #expect(artifact.checksumSha256 == "e3b0c44298fc1c149afbf4c8996fb924")
    }

    @Test func artifactWithNilOptionals() throws {
        let json = """
        {
            "id": "art-2",
            "name": "file.bin",
            "path": "files/file.bin",
            "size_bytes": 100,
            "download_count": 0,
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let artifact = try JSONDecoder().decode(Artifact.self, from: json)
        #expect(artifact.repositoryKey == nil)
        #expect(artifact.version == nil)
        #expect(artifact.contentType == nil)
        #expect(artifact.checksumSha256 == nil)
    }

    @Test func artifactIsHashable() throws {
        let a = try JSONDecoder().decode(Artifact.self, from: """
        {"id":"a1","name":"n","path":"p","size_bytes":0,"download_count":0,"created_at":""}
        """.data(using: .utf8)!)
        let b = try JSONDecoder().decode(Artifact.self, from: """
        {"id":"a2","name":"n","path":"p","size_bytes":0,"download_count":0,"created_at":""}
        """.data(using: .utf8)!)

        var set: Set<Artifact> = [a, b]
        #expect(set.count == 2)
        set.insert(a)
        #expect(set.count == 2)
    }

    @Test func artifactListResponseDecodes() throws {
        let json = """
        {
            "items": [],
            "pagination": {"page": 1, "per_page": 50, "total": 0}
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ArtifactListResponse.self, from: json)
        #expect(response.items.isEmpty)
        #expect(response.pagination?.total == 0)
    }

    @Test func artifactListResponseNilPagination() throws {
        let json = """
        {"items": [], "pagination": null}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ArtifactListResponse.self, from: json)
        #expect(response.pagination == nil)
    }
}

// MARK: - Promotion Models

@Suite("Promotion Model Tests")
struct PromotionModelTests {

    @Test func policyStatusRawValues() {
        #expect(PolicyStatus.passing.rawValue == "passing")
        #expect(PolicyStatus.failing.rawValue == "failing")
        #expect(PolicyStatus.warning.rawValue == "warning")
        #expect(PolicyStatus.pending.rawValue == "pending")
    }

    @Test func policyStatusColors() {
        #expect(PolicyStatus.passing.color == "green")
        #expect(PolicyStatus.failing.color == "red")
        #expect(PolicyStatus.warning.color == "yellow")
        #expect(PolicyStatus.pending.color == "gray")
    }

    @Test func policyStatusDecodesFromJSON() throws {
        let json = "\"passing\"".data(using: .utf8)!
        let status = try JSONDecoder().decode(PolicyStatus.self, from: json)
        #expect(status == .passing)
    }

    @Test func policyStatusEncodesRoundTrip() throws {
        for status in [PolicyStatus.passing, .failing, .warning, .pending] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(PolicyStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test func stagingArtifactDecodesFromJSON() throws {
        let json = """
        {
            "id": "sa-1",
            "repository_key": "staging-maven",
            "name": "my-lib",
            "path": "com/example/my-lib/2.0.0/my-lib-2.0.0.jar",
            "version": "2.0.0",
            "content_type": "application/java-archive",
            "size_bytes": 512000,
            "policy_status": "passing",
            "cve_summary": {
                "total": 3,
                "critical": 0,
                "high": 1,
                "medium": 1,
                "low": 1,
                "unpatched": 0
            },
            "license_summary": null,
            "violations": [],
            "created_at": "2024-05-01T12:00:00Z",
            "promoted_at": null,
            "promoted_by": null,
            "promoted_to_repo": null
        }
        """.data(using: .utf8)!

        let artifact = try JSONDecoder().decode(StagingArtifact.self, from: json)
        #expect(artifact.id == "sa-1")
        #expect(artifact.repositoryKey == "staging-maven")
        #expect(artifact.policyStatus == "passing")
        #expect(artifact.cveSummary?.total == 3)
        #expect(artifact.cveSummary?.critical == 0)
        #expect(artifact.cveSummary?.high == 1)
        #expect(artifact.licenseSummary == nil)
        #expect(artifact.violations?.isEmpty == true)
        #expect(artifact.promotedAt == nil)
    }

    @Test func stagingArtifactHashableById() {
        // Two staging artifacts with the same id should be equal
        let json1 = """
        {"id":"same","repository_key":"r","name":"n","path":"p","size_bytes":0,"policy_status":"pending","created_at":""}
        """.data(using: .utf8)!
        let json2 = """
        {"id":"same","repository_key":"r2","name":"n2","path":"p2","size_bytes":100,"policy_status":"passing","created_at":"now"}
        """.data(using: .utf8)!

        let a = try! JSONDecoder().decode(StagingArtifact.self, from: json1)
        let b = try! JSONDecoder().decode(StagingArtifact.self, from: json2)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func cveSummaryRoundTrip() throws {
        let json = """
        {"total": 10, "critical": 2, "high": 3, "medium": 4, "low": 1, "unpatched": 5}
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(CveSummary.self, from: json)
        #expect(summary.total == 10)
        #expect(summary.critical == 2)
        #expect(summary.unpatched == 5)

        let encoded = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(CveSummary.self, from: encoded)
        #expect(decoded.total == summary.total)
    }

    @Test func licenseSummaryDecodesWithLicenses() throws {
        let json = """
        {
            "total": 5,
            "approved": 3,
            "rejected": 1,
            "unknown": 1,
            "licenses": ["MIT", "Apache-2.0", "GPL-3.0"]
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(LicenseSummary.self, from: json)
        #expect(summary.total == 5)
        #expect(summary.approved == 3)
        #expect(summary.licenses?.count == 3)
        #expect(summary.licenses?.contains("MIT") == true)
    }

    @Test func licenseSummaryNilLicenses() throws {
        let json = """
        {"total": 0, "approved": 0, "rejected": 0, "unknown": 0}
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(LicenseSummary.self, from: json)
        #expect(summary.licenses == nil)
    }

    @Test func promotionResponseRoundTrip() throws {
        let original = PromotionResponse(
            success: true,
            artifactId: "art-1",
            targetRepoKey: "release-maven",
            promotedPath: "com/example/lib/1.0.0/lib.jar",
            message: "Promoted successfully",
            warnings: ["Minor policy warning"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromotionResponse.self, from: data)
        #expect(decoded.success == true)
        #expect(decoded.artifactId == "art-1")
        #expect(decoded.targetRepoKey == "release-maven")
        #expect(decoded.promotedPath == "com/example/lib/1.0.0/lib.jar")
        #expect(decoded.message == "Promoted successfully")
        #expect(decoded.warnings == ["Minor policy warning"])
    }

    @Test func promotionResponseNilOptionals() throws {
        let original = PromotionResponse(
            success: false,
            artifactId: "art-2",
            targetRepoKey: "target",
            promotedPath: nil,
            message: nil,
            warnings: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromotionResponse.self, from: data)
        #expect(decoded.promotedPath == nil)
        #expect(decoded.message == nil)
        #expect(decoded.warnings == nil)
    }

    @Test func promotionRequestEncodesSnakeCase() throws {
        let req = PromotionRequest(targetRepoKey: "prod-maven", force: true, comment: "Approved by QA")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["target_repo_key"] as? String == "prod-maven")
        #expect(json?["force"] as? Bool == true)
        #expect(json?["comment"] as? String == "Approved by QA")
    }

    @Test func bulkPromotionResponseRoundTrip() throws {
        let result = BulkPromotionResult(
            artifactId: "a1",
            success: true,
            message: "OK",
            promotedPath: "/path"
        )
        let original = BulkPromotionResponse(
            totalRequested: 2,
            totalSucceeded: 1,
            totalFailed: 1,
            results: [result]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BulkPromotionResponse.self, from: data)
        #expect(decoded.totalRequested == 2)
        #expect(decoded.totalSucceeded == 1)
        #expect(decoded.totalFailed == 1)
        #expect(decoded.results.count == 1)
        #expect(decoded.results[0].artifactId == "a1")
    }

    @Test func promotionHistoryEntryRoundTrip() throws {
        let original = PromotionHistoryEntry(
            id: "ph-1",
            artifactId: "art-1",
            artifactName: "my-lib",
            artifactVersion: "1.0.0",
            sourceRepoKey: "staging",
            targetRepoKey: "release",
            promotedBy: "user-id-1",
            promotedByUsername: "jdoe",
            comment: "Release approved",
            wasForced: false,
            promotedAt: "2024-06-01T10:00:00Z"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromotionHistoryEntry.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.artifactId == original.artifactId)
        #expect(decoded.artifactName == original.artifactName)
        #expect(decoded.artifactVersion == original.artifactVersion)
        #expect(decoded.sourceRepoKey == original.sourceRepoKey)
        #expect(decoded.targetRepoKey == original.targetRepoKey)
        #expect(decoded.promotedBy == original.promotedBy)
        #expect(decoded.promotedByUsername == original.promotedByUsername)
        #expect(decoded.comment == original.comment)
        #expect(decoded.wasForced == false)
    }

    @Test func promotionHistoryEntryNilOptionals() throws {
        let original = PromotionHistoryEntry(
            id: "ph-2",
            artifactId: "art-2",
            artifactName: "other-lib",
            artifactVersion: nil,
            sourceRepoKey: "staging",
            targetRepoKey: "release",
            promotedBy: "uid",
            promotedByUsername: nil,
            comment: nil,
            wasForced: true,
            promotedAt: "2024-07-01T00:00:00Z"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromotionHistoryEntry.self, from: data)
        #expect(decoded.artifactVersion == nil)
        #expect(decoded.promotedByUsername == nil)
        #expect(decoded.comment == nil)
        #expect(decoded.wasForced == true)
    }

    @Test func policyViolationDecodesFromJSON() throws {
        let json = """
        {
            "id": "pv-1",
            "policy_id": "pol-1",
            "policy_name": "No Critical CVEs",
            "severity": "critical",
            "message": "Found critical CVE",
            "details": "CVE-2024-1234",
            "created_at": "2024-05-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let violation = try JSONDecoder().decode(PolicyViolation.self, from: json)
        #expect(violation.id == "pv-1")
        #expect(violation.policyId == "pol-1")
        #expect(violation.policyName == "No Critical CVEs")
        #expect(violation.severity == "critical")
        #expect(violation.details == "CVE-2024-1234")
    }

    @Test func stagingRepositoryDecodesAndHashesById() throws {
        let json = """
        {
            "id": "sr-1",
            "key": "staging-npm",
            "name": "NPM Staging",
            "format": "npm",
            "target_repo_key": "npm-release",
            "artifact_count": 10,
            "pending_count": 3,
            "passing_count": 5,
            "failing_count": 2,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-06-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let repo = try JSONDecoder().decode(StagingRepository.self, from: json)
        #expect(repo.id == "sr-1")
        #expect(repo.key == "staging-npm")
        #expect(repo.artifactCount == 10)
        #expect(repo.pendingCount == 3)

        let json2 = """
        {
            "id": "sr-1",
            "key": "different",
            "name": "Different",
            "format": "maven",
            "artifact_count": 0,
            "pending_count": 0,
            "passing_count": 0,
            "failing_count": 0,
            "created_at": "",
            "updated_at": ""
        }
        """.data(using: .utf8)!
        let repo2 = try JSONDecoder().decode(StagingRepository.self, from: json2)
        #expect(repo == repo2) // Same id means equal
    }
}

// MARK: - VirtualMember Models

@Suite("VirtualMember Model Tests")
struct VirtualMemberModelTests {

    @Test func virtualMemberRoundTrip() throws {
        let original = VirtualMember(
            id: "vm-1",
            memberRepoId: "repo-id-1",
            memberRepoKey: "maven-local",
            memberRepoName: "Maven Local",
            memberRepoType: "local",
            priority: 1,
            createdAt: "2024-01-01T00:00:00Z"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VirtualMember.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.memberRepoId == original.memberRepoId)
        #expect(decoded.memberRepoKey == original.memberRepoKey)
        #expect(decoded.memberRepoName == original.memberRepoName)
        #expect(decoded.memberRepoType == original.memberRepoType)
        #expect(decoded.priority == 1)
    }

    @Test func virtualMembersResponseDecodes() throws {
        let json = """
        {
            "items": [
                {
                    "id": "vm-1",
                    "member_repo_id": "r1",
                    "member_repo_key": "local",
                    "member_repo_name": "Local",
                    "member_repo_type": "local",
                    "priority": 1,
                    "created_at": "2024-01-01T00:00:00Z"
                },
                {
                    "id": "vm-2",
                    "member_repo_id": "r2",
                    "member_repo_key": "remote",
                    "member_repo_name": "Remote",
                    "member_repo_type": "proxy",
                    "priority": 2,
                    "created_at": "2024-01-02T00:00:00Z"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(VirtualMembersResponse.self, from: json)
        #expect(response.items.count == 2)
        #expect(response.items[0].priority < response.items[1].priority)
    }

    @Test func virtualMembersResponseEmptyItems() throws {
        let json = """
        {"items": []}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(VirtualMembersResponse.self, from: json)
        #expect(response.items.isEmpty)
    }

    @Test func addMemberRequestEncodesSnakeCase() throws {
        let req = AddMemberRequest(memberKey: "npm-remote", priority: 5)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["member_key"] as? String == "npm-remote")
        #expect(json?["priority"] as? Int == 5)
    }

    @Test func addMemberRequestNilPriority() throws {
        let req = AddMemberRequest(memberKey: "maven-local", priority: nil)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["member_key"] as? String == "maven-local")
        // priority should be null or absent
        #expect(json?["priority"] is NSNull || json?["priority"] == nil)
    }

    @Test func memberPriorityEncodesSnakeCase() throws {
        let mp = MemberPriority(memberKey: "pypi-local", priority: 3)
        let data = try JSONEncoder().encode(mp)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["member_key"] as? String == "pypi-local")
        #expect(json?["priority"] as? Int == 3)
    }

    @Test func reorderMembersRequestRoundTrip() throws {
        let req = ReorderMembersRequest(members: [
            MemberPriority(memberKey: "a", priority: 1),
            MemberPriority(memberKey: "b", priority: 2),
        ])
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(ReorderMembersRequest.self, from: data)
        #expect(decoded.members.count == 2)
        #expect(decoded.members[0].memberKey == "a")
        #expect(decoded.members[1].priority == 2)
    }
}

// MARK: - Operations Models

@Suite("Operations Model Tests")
struct OperationsModelTests {

    @Test func adminStatsDecodesFromJSON() throws {
        let json = """
        {
            "total_repositories": 25,
            "total_artifacts": 1500,
            "total_storage_bytes": 5368709120,
            "total_downloads": 50000,
            "total_users": 100,
            "active_peers": 3,
            "pending_sync_tasks": 12
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(AdminStats.self, from: json)
        #expect(stats.totalRepositories == 25)
        #expect(stats.totalArtifacts == 1500)
        #expect(stats.totalStorageBytes == 5368709120)
        #expect(stats.totalDownloads == 50000)
        #expect(stats.totalUsers == 100)
        #expect(stats.activePeers == 3)
        #expect(stats.pendingSyncTasks == 12)
    }

    @Test func healthResponseDecodesFromJSON() throws {
        let json = """
        {
            "status": "healthy",
            "version": "1.2.0",
            "demo_mode": false,
            "checks": {
                "database": {"status": "healthy"},
                "storage": {"status": "healthy"},
                "search": {"status": "degraded"}
            }
        }
        """.data(using: .utf8)!

        let health = try JSONDecoder().decode(HealthResponse.self, from: json)
        #expect(health.status == "healthy")
        #expect(health.version == "1.2.0")
        #expect(health.demoMode == false)
        #expect(health.checks?.count == 3)
        #expect(health.checks?["database"]?.status == "healthy")
        #expect(health.checks?["search"]?.status == "degraded")
    }

    @Test func healthResponseMinimalJSON() throws {
        let json = """
        {"status": "healthy"}
        """.data(using: .utf8)!

        let health = try JSONDecoder().decode(HealthResponse.self, from: json)
        #expect(health.status == "healthy")
        #expect(health.version == nil)
        #expect(health.demoMode == nil)
        #expect(health.checks == nil)
    }

    @Test func storageBreakdownDecodesFromJSON() throws {
        let json = """
        {
            "repository_id": "repo-1",
            "repository_key": "maven-local",
            "repository_name": "Maven Local",
            "format": "maven",
            "artifact_count": 250,
            "storage_bytes": 1073741824,
            "download_count": 5000,
            "last_upload_at": "2024-06-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let breakdown = try JSONDecoder().decode(StorageBreakdown.self, from: json)
        #expect(breakdown.repositoryId == "repo-1")
        #expect(breakdown.id == "repo-1") // Identifiable uses repositoryId
        #expect(breakdown.repositoryKey == "maven-local")
        #expect(breakdown.storageBytes == 1073741824)
        #expect(breakdown.lastUploadAt == "2024-06-15T10:30:00Z")
    }

    @Test func storageBreakdownNilLastUpload() throws {
        let json = """
        {
            "repository_id": "r2",
            "repository_key": "k",
            "repository_name": "n",
            "format": "npm",
            "artifact_count": 0,
            "storage_bytes": 0,
            "download_count": 0
        }
        """.data(using: .utf8)!

        let breakdown = try JSONDecoder().decode(StorageBreakdown.self, from: json)
        #expect(breakdown.lastUploadAt == nil)
    }

    @Test func downloadTrendDecodesFromJSON() throws {
        let json = """
        {"date": "2024-06-15", "download_count": 1500}
        """.data(using: .utf8)!

        let trend = try JSONDecoder().decode(DownloadTrend.self, from: json)
        #expect(trend.date == "2024-06-15")
        #expect(trend.id == "2024-06-15") // Identifiable uses date
        #expect(trend.downloadCount == 1500)
    }

    @Test func storageGrowthDecodesFromJSON() throws {
        let json = """
        {
            "period_start": "2024-06-01",
            "period_end": "2024-06-30",
            "storage_bytes_start": 1000000000,
            "storage_bytes_end": 1200000000,
            "storage_growth_bytes": 200000000,
            "storage_growth_percent": 20.0,
            "artifacts_start": 500,
            "artifacts_end": 600,
            "artifacts_added": 100,
            "downloads_in_period": 3000
        }
        """.data(using: .utf8)!

        let growth = try JSONDecoder().decode(StorageGrowth.self, from: json)
        #expect(growth.periodStart == "2024-06-01")
        #expect(growth.storageGrowthBytes == 200000000)
        #expect(growth.storageGrowthPercent == 20.0)
        #expect(growth.artifactsAdded == 100)
    }

    @Test func healthLogEntryDecodesAndHasComputedId() throws {
        let json = """
        {
            "service_name": "database",
            "status": "healthy",
            "previous_status": "degraded",
            "message": "Connection restored",
            "response_time_ms": 15,
            "checked_at": "2024-06-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(HealthLogEntry.self, from: json)
        #expect(entry.serviceName == "database")
        #expect(entry.id == "database-2024-06-15T10:00:00Z")
        #expect(entry.message == "Connection restored")
        #expect(entry.responseTimeMs == 15)
    }

    @Test func alertStateDecodesFromJSON() throws {
        let json = """
        {
            "service_name": "search",
            "current_status": "critical",
            "consecutive_failures": 5,
            "last_alert_sent_at": "2024-06-15T09:00:00Z",
            "suppressed_until": null,
            "updated_at": "2024-06-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let alert = try JSONDecoder().decode(AlertState.self, from: json)
        #expect(alert.serviceName == "search")
        #expect(alert.id == "search")
        #expect(alert.currentStatus == "critical")
        #expect(alert.consecutiveFailures == 5)
        #expect(alert.lastAlertSentAt == "2024-06-15T09:00:00Z")
        #expect(alert.suppressedUntil == nil)
    }
}

// MARK: - Security Models

@Suite("Security Model Tests")
struct SecurityModelTests {

    @Test func dashboardSummaryDecodesFromJSON() throws {
        let json = """
        {
            "repos_with_scanning": 10,
            "total_scans": 500,
            "total_findings": 120,
            "critical_findings": 5,
            "high_findings": 15,
            "repos_grade_a": 7,
            "repos_grade_f": 1
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(DashboardSummary.self, from: json)
        #expect(summary.reposWithScanning == 10)
        #expect(summary.totalScans == 500)
        #expect(summary.totalFindings == 120)
        #expect(summary.criticalFindings == 5)
        #expect(summary.highFindings == 15)
        #expect(summary.reposGradeA == 7)
        #expect(summary.reposGradeF == 1)
    }

    @Test func scanResultDecodesFromJSON() throws {
        let json = """
        {
            "id": "scan-1",
            "artifact_id": "art-1",
            "scan_type": "vulnerability",
            "status": "completed",
            "findings_count": 8,
            "critical_count": 1,
            "high_count": 2,
            "medium_count": 3,
            "low_count": 2,
            "started_at": "2024-06-15T09:00:00Z",
            "completed_at": "2024-06-15T09:05:00Z",
            "error_message": null,
            "artifact_name": "my-lib",
            "artifact_version": "1.0.0"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ScanResult.self, from: json)
        #expect(result.id == "scan-1")
        #expect(result.artifactId == "art-1")
        #expect(result.scanType == "vulnerability")
        #expect(result.status == "completed")
        #expect(result.findingsCount == 8)
        #expect(result.criticalCount == 1)
        #expect(result.highCount == 2)
        #expect(result.mediumCount == 3)
        #expect(result.lowCount == 2)
        #expect(result.startedAt == "2024-06-15T09:00:00Z")
        #expect(result.completedAt == "2024-06-15T09:05:00Z")
        #expect(result.errorMessage == nil)
        #expect(result.artifactName == "my-lib")
        #expect(result.artifactVersion == "1.0.0")
    }

    @Test func scanResultNilOptionals() throws {
        let json = """
        {
            "id": "s2",
            "artifact_id": "a2",
            "scan_type": "license",
            "status": "pending",
            "findings_count": 0,
            "critical_count": 0,
            "high_count": 0,
            "medium_count": 0,
            "low_count": 0
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ScanResult.self, from: json)
        #expect(result.startedAt == nil)
        #expect(result.completedAt == nil)
        #expect(result.errorMessage == nil)
        #expect(result.artifactName == nil)
        #expect(result.artifactVersion == nil)
    }

    @Test func scanFindingDecodesFromJSON() throws {
        let json = """
        {
            "id": "f-1",
            "scan_result_id": "scan-1",
            "artifact_id": "art-1",
            "severity": "high",
            "title": "CVE-2024-1234",
            "description": "Remote code execution vulnerability",
            "cve_id": "CVE-2024-1234",
            "affected_component": "libxml2",
            "affected_version": "2.9.0",
            "fixed_version": "2.9.14",
            "source": "trivy",
            "source_url": "https://nvd.nist.gov/vuln/detail/CVE-2024-1234",
            "is_acknowledged": false,
            "acknowledged_by": null,
            "acknowledged_reason": null,
            "acknowledged_at": null,
            "created_at": "2024-06-15T09:05:00Z"
        }
        """.data(using: .utf8)!

        let finding = try JSONDecoder().decode(ScanFinding.self, from: json)
        #expect(finding.id == "f-1")
        #expect(finding.scanResultId == "scan-1")
        #expect(finding.severity == "high")
        #expect(finding.title == "CVE-2024-1234")
        #expect(finding.cveId == "CVE-2024-1234")
        #expect(finding.affectedComponent == "libxml2")
        #expect(finding.fixedVersion == "2.9.14")
        #expect(finding.isAcknowledged == false)
        #expect(finding.acknowledgedBy == nil)
    }

    @Test func scanFindingAcknowledged() throws {
        let json = """
        {
            "id": "f-2",
            "scan_result_id": "s2",
            "artifact_id": "a2",
            "severity": "low",
            "title": "Info leak",
            "is_acknowledged": true,
            "acknowledged_by": "admin",
            "acknowledged_reason": "False positive",
            "acknowledged_at": "2024-06-16T00:00:00Z"
        }
        """.data(using: .utf8)!

        let finding = try JSONDecoder().decode(ScanFinding.self, from: json)
        #expect(finding.isAcknowledged == true)
        #expect(finding.acknowledgedBy == "admin")
        #expect(finding.acknowledgedReason == "False positive")
    }

    @Test func scanListResponseDecodes() throws {
        let json = """
        {"items": [], "total": 0}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ScanListResponse.self, from: json)
        #expect(response.items.isEmpty)
        #expect(response.total == 0)
    }

    @Test func scanFindingListResponseDecodes() throws {
        let json = """
        {"items": []}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ScanFindingListResponse.self, from: json)
        #expect(response.items.isEmpty)
    }

    @Test func repoSecurityScoreDecodesFromJSON() throws {
        let json = """
        {
            "id": "rss-1",
            "repository_id": "repo-1",
            "grade": "A",
            "score": 95,
            "critical_count": 0,
            "high_count": 1,
            "medium_count": 3,
            "low_count": 5
        }
        """.data(using: .utf8)!

        let score = try JSONDecoder().decode(RepoSecurityScore.self, from: json)
        #expect(score.id == "rss-1")
        #expect(score.repositoryId == "repo-1")
        #expect(score.grade == "A")
        #expect(score.score == 95)
        #expect(score.criticalCount == 0)
        #expect(score.highCount == 1)
    }

    @Test func repoSecurityScoreIsHashable() throws {
        let json1 = """
        {"id":"rss-1","repository_id":"r1","grade":"A","score":95,"critical_count":0,"high_count":0,"medium_count":0,"low_count":0}
        """.data(using: .utf8)!
        let json2 = """
        {"id":"rss-2","repository_id":"r2","grade":"B","score":80,"critical_count":1,"high_count":2,"medium_count":3,"low_count":4}
        """.data(using: .utf8)!

        let s1 = try JSONDecoder().decode(RepoSecurityScore.self, from: json1)
        let s2 = try JSONDecoder().decode(RepoSecurityScore.self, from: json2)
        let set: Set<RepoSecurityScore> = [s1, s2]
        #expect(set.count == 2)
    }

    @Test func repoSecurityConfigRoundTrip() throws {
        let original = RepoSecurityConfig(
            scanEnabled: true,
            scanOnUpload: true,
            scanOnProxy: false,
            blockOnPolicyViolation: true,
            severityThreshold: "critical"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RepoSecurityConfig.self, from: data)
        #expect(decoded.scanEnabled == true)
        #expect(decoded.scanOnUpload == true)
        #expect(decoded.scanOnProxy == false)
        #expect(decoded.blockOnPolicyViolation == true)
        #expect(decoded.severityThreshold == "critical")
    }

    @Test func repoSecurityInfoResponseNilConfig() throws {
        let json = """
        {"config": null}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RepoSecurityInfoResponse.self, from: json)
        #expect(response.config == nil)
    }
}

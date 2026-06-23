import Testing
import Foundation
@testable import ArtifactKeeper

// Verifies the 1.2.1 profile-token path regression is routed to the current spec surface.
// The v1.2.1 spec removed /api/v1/profile/api-keys and /profile/access-tokens. Tokens now
// live at /api/v1/auth/tokens (create, delete by id) and /api/v1/users/{id}/tokens (list).
//
// Each test captures the outgoing request path via MockURLProtocol and asserts it targets
// the 1.2.1 surface and never the removed /profile/ paths. MockURLProtocol and makeTestClient
// are defined in APIClientNetworkTests.swift (same test target).

// A sendable box for recording the paths a sequence of requests hit.
final class PathRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _paths: [String] = []
    func record(_ path: String) {
        lock.lock(); defer { lock.unlock() }
        _paths.append(path)
    }
    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return _paths
    }
}

private func okResponse(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
}

/// Build an APIClient backed by MockURLProtocol. Defined locally because the
/// equivalent helper in APIClientNetworkTests.swift is file-private.
private func makeTokenTestClient(baseURL: String = "https://test-api.example.com") -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    config.timeoutIntervalForRequest = 5
    let session = URLSession(configuration: config)
    return APIClient(baseURL: baseURL, session: session)
}

@Suite("API Token Path Regression Tests", .serialized)
struct APITokenPathRegressionTests {

    init() {
        MockURLProtocol.reset()
    }

    @Test func listApiKeysTargetsUserTokensPath() async throws {
        let client = makeTokenTestClient()
        let recorder = PathRecorder()
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            recorder.record(path)
            if path == "/api/v1/auth/me" {
                return okResponse(request.url!, """
                {"id": "user-7", "username": "alice", "email": "a@b.c", "is_admin": false, "totp_enabled": false}
                """)
            }
            return okResponse(request.url!, "{\"items\": []}")
        }

        _ = try await client.listApiKeys()

        #expect(recorder.paths.contains("/api/v1/users/user-7/tokens"))
        #expect(!recorder.paths.contains(where: { $0.contains("/profile/") }))
    }

    @Test func createApiKeyTargetsAuthTokensPath() async throws {
        let client = makeTokenTestClient()
        let recorder = PathRecorder()
        MockURLProtocol.requestHandler = { request in
            recorder.record(request.url!.path)
            return okResponse(request.url!, """
            {"id": "tok-1", "name": "ci", "token": "ak_secretvalue"}
            """, status: 201)
        }

        let result = try await client.createApiKey(name: "ci", scopes: ["read"], expiresInDays: 90)

        #expect(recorder.paths.contains("/api/v1/auth/tokens"))
        #expect(!recorder.paths.contains(where: { $0.contains("/profile/") }))
        #expect(result.key == "ak_secretvalue")
    }

    @Test func deleteApiKeyTargetsAuthTokensPath() async throws {
        let client = makeTokenTestClient()
        let recorder = PathRecorder()
        MockURLProtocol.requestHandler = { request in
            recorder.record(request.url!.path)
            return okResponse(request.url!, "")
        }

        try await client.deleteApiKey("tok-9")

        #expect(recorder.paths.contains("/api/v1/auth/tokens/tok-9"))
        #expect(!recorder.paths.contains(where: { $0.contains("/profile/") }))
    }

    @Test func listAccessTokensTargetsUserTokensPath() async throws {
        let client = makeTokenTestClient()
        let recorder = PathRecorder()
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            recorder.record(path)
            if path == "/api/v1/auth/me" {
                return okResponse(request.url!, """
                {"id": "user-9", "username": "bob", "email": "b@b.c", "is_admin": true, "totp_enabled": false}
                """)
            }
            return okResponse(request.url!, "{\"items\": []}")
        }

        _ = try await client.listAccessTokens()

        #expect(recorder.paths.contains("/api/v1/users/user-9/tokens"))
        #expect(!recorder.paths.contains(where: { $0.contains("/profile/") }))
    }

    @Test func createAccessTokenTargetsAuthTokensPath() async throws {
        let client = makeTokenTestClient()
        let recorder = PathRecorder()
        MockURLProtocol.requestHandler = { request in
            recorder.record(request.url!.path)
            return okResponse(request.url!, """
            {"id": "tok-2", "name": "deploy", "token": "ak_secretvalue2"}
            """, status: 201)
        }

        let result = try await client.createAccessToken(name: "deploy", scopes: ["write"], expiresInDays: nil)

        #expect(recorder.paths.contains("/api/v1/auth/tokens"))
        #expect(!recorder.paths.contains(where: { $0.contains("/profile/") }))
        #expect(result.token == "ak_secretvalue2")
    }

    @Test func deleteAccessTokenTargetsAuthTokensPath() async throws {
        let client = makeTokenTestClient()
        let recorder = PathRecorder()
        MockURLProtocol.requestHandler = { request in
            recorder.record(request.url!.path)
            return okResponse(request.url!, "")
        }

        try await client.deleteAccessToken("tok-5")

        #expect(recorder.paths.contains("/api/v1/auth/tokens/tok-5"))
        #expect(!recorder.paths.contains(where: { $0.contains("/profile/") }))
    }
}

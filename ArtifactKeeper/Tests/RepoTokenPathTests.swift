import Testing
import Foundation
@testable import ArtifactKeeper

// Path-pinning tests for the raw-request repository-token methods on APIClient.
// Each test drives the real production method through a per-instance MockSession
// (isolated handler, parallel-safe) and asserts the outgoing request path and
// method. A canned 200 body lets the method decode and return.

@Suite("Repository Token Path Tests")
struct RepoTokenPathTests {

    private func okResponse(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }

    private let tokenJSON = """
    {
      "id": "tok-1", "name": "ci", "token_prefix": "ak_abc",
      "scopes": ["read"], "created_at": "2026-01-01T00:00:00Z",
      "is_expired": false, "is_revoked": false
    }
    """

    @Test func listRepoTokensTargetsTokensPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            return self.okResponse(request.url!, #"{"items":[]}"#)
        }

        _ = try await mock.client.listRepoTokens(repoKey: "maven-prod")

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/tokens"))
    }

    @Test func getRepoTokenTargetsTokenByIdPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            return self.okResponse(request.url!, self.tokenJSON)
        }

        let token = try await mock.client.getRepoToken(repoKey: "maven-prod", tokenId: "tok-1")

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/tokens/tok-1"))
        #expect(token.id == "tok-1")
    }

    @Test func createRepoTokenTargetsTokensPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            return self.okResponse(request.url!, """
            {"id":"tok-9","name":"ci","token":"ak_secret","repository_key":"maven-prod"}
            """, status: 201)
        }

        let result = try await mock.client.createRepoToken(
            repoKey: "maven-prod",
            name: "ci",
            scopes: ["read", "write"],
            expiresInDays: 90
        )

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/tokens"))
        #expect(methodBox.methods.contains("POST"))
        #expect(result.token == "ak_secret")
    }

    @Test func revokeRepoTokenTargetsTokenByIdPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            return self.okResponse(request.url!, "")
        }

        try await mock.client.revokeRepoToken(repoKey: "maven-prod", tokenId: "tok-7")

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/tokens/tok-7"))
        #expect(methodBox.methods.contains("DELETE"))
    }
}

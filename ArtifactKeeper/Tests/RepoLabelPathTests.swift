import Testing
import Foundation
@testable import ArtifactKeeper

// Path-pinning tests for the raw-request repository-label methods on APIClient.
// Each drives the real production method through a per-instance MockSession and
// asserts the outgoing path and HTTP method.

@Suite("Repository Label Path Tests")
struct RepoLabelPathTests {

    private func okResponse(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }

    private let labelJSON = """
    {"id":"lbl-1","repository_id":"repo-1","key":"team","value":"infra","created_at":"2026-01-01T00:00:00Z"}
    """

    @Test func listRepoLabelsTargetsLabelsPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            return self.okResponse(request.url!, #"{"items":[],"total":0}"#)
        }

        _ = try await mock.client.listRepoLabels(repoKey: "maven-prod")

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/labels"))
    }

    @Test func setRepoLabelsTargetsLabelsPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            return self.okResponse(request.url!, #"{"items":[],"total":0}"#)
        }

        _ = try await mock.client.setRepoLabels(
            repoKey: "maven-prod",
            labels: [RepoLabelEntry(key: "team", value: "infra")]
        )

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/labels"))
        #expect(methodBox.methods.contains("PUT"))
    }

    @Test func addRepoLabelTargetsLabelByKeyPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            return self.okResponse(request.url!, self.labelJSON)
        }

        let label = try await mock.client.addRepoLabel(repoKey: "maven-prod", key: "team", value: "infra")

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/labels/team"))
        #expect(methodBox.methods.contains("POST"))
        #expect(label.key == "team")
    }

    @Test func deleteRepoLabelTargetsLabelByKeyPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            return self.okResponse(request.url!, "")
        }

        try await mock.client.deleteRepoLabel(repoKey: "maven-prod", key: "team")

        #expect(recorder.paths.contains("/api/v1/repositories/maven-prod/labels/team"))
        #expect(methodBox.methods.contains("DELETE"))
    }
}

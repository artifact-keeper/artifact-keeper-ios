import Testing
import Foundation
@testable import ArtifactKeeper

// Path-pinning tests for the raw-request CVE history and license compliance
// methods on APIClient. Each test drives the real production method through a
// per-instance MockSession (isolated handler slot, parallel-safe) and asserts the
// outgoing request path and method. A canned 200 body lets the method decode and
// return normally.

@Suite("CVE History & License Compliance Path Tests")
struct CveLicensePathTests {

    private func okResponse(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }

    @Test func getCveHistoryByArtifactTargetsByArtifactPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            return self.okResponse(request.url!, "[]")
        }

        _ = try await mock.client.getCveHistoryByArtifact(artifactId: "art-7")

        #expect(recorder.paths.contains("/api/v1/sbom/cve/history/by-artifact/art-7"))
    }

    @Test func getCveHistoryByCveTargetsByCvePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            return self.okResponse(request.url!, "[]")
        }

        _ = try await mock.client.getCveHistoryByCve(cveId: "CVE-2024-1234")

        #expect(recorder.paths.contains("/api/v1/sbom/cve/history/by-cve/CVE-2024-1234"))
    }

    @Test func getCveHistoryTargetsHistoryByIdPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            // Minimal CveHistoryEntry shape so the method decodes and returns.
            return self.okResponse(request.url!, """
            {
              "id": "hist-9",
              "artifact_id": "art-1",
              "cve_id": "CVE-2024-1234",
              "first_detected_at": "2024-01-01T00:00:00Z",
              "last_detected_at": "2024-01-02T00:00:00Z",
              "status": "open",
              "created_at": "2024-01-01T00:00:00Z",
              "updated_at": "2024-01-02T00:00:00Z"
            }
            """)
        }

        let entry = try await mock.client.getCveHistory(id: "hist-9")

        #expect(recorder.paths.contains("/api/v1/sbom/cve/history/hist-9"))
        #expect(entry.id == "hist-9")
        #expect(entry.cveId == "CVE-2024-1234")
    }

    @Test func checkLicenseComplianceTargetsCheckCompliancePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            return self.okResponse(request.url!, """
            {"compliant": true, "violations": [], "warnings": []}
            """)
        }

        let result = try await mock.client.checkLicenseCompliance(licenses: ["MIT", "GPL-3.0"])

        #expect(recorder.paths.contains("/api/v1/sbom/check-compliance"))
        #expect(methodBox.methods.contains("POST"))
        #expect(result.compliant)
    }
}

/// Records the HTTP methods seen across a sequence of requests.
final class MethodRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _methods: [String] = []
    func record(_ method: String) {
        lock.lock(); defer { lock.unlock() }
        _methods.append(method)
    }
    var methods: [String] {
        lock.lock(); defer { lock.unlock() }
        return _methods
    }
}

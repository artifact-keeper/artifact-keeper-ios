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

    @Test func updateCveStatusTargetsByArtifactByCvePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let recorder = PathRecorder()
        let methodBox = MethodRecorder()
        let bodyBox = BodyRecorder()
        mock.handler = { request in
            recorder.record(request.url!.path)
            methodBox.record(request.httpMethod ?? "")
            if let stream = request.httpBodyStream {
                bodyBox.record(BodyRecorder.readStream(stream))
            } else if let body = request.httpBody {
                bodyBox.record(String(data: body, encoding: .utf8) ?? "")
            }
            return self.okResponse(request.url!, """
            {
              "id": "hist-3",
              "artifact_id": "art-1",
              "cve_id": "CVE-2024-9999",
              "first_detected_at": "2024-01-01T00:00:00Z",
              "last_detected_at": "2024-01-02T00:00:00Z",
              "status": "acknowledged",
              "created_at": "2024-01-01T00:00:00Z",
              "updated_at": "2024-01-02T00:00:00Z"
            }
            """)
        }

        let updated = try await mock.client.updateCveStatusByArtifactCve(
            artifactId: "art-1",
            cveId: "CVE-2024-9999",
            status: "acknowledged",
            reason: "investigated"
        )

        #expect(recorder.paths.contains("/api/v1/sbom/cve/status/by-artifact/art-1/by-cve/CVE-2024-9999"))
        #expect(methodBox.methods.contains("POST"))
        #expect(updated.status == "acknowledged")
        #expect(bodyBox.bodies.first?.contains("acknowledged") == true)
        #expect(bodyBox.bodies.first?.contains("investigated") == true)
    }
}

/// Records request body strings across a sequence of requests.
final class BodyRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _bodies: [String] = []
    func record(_ body: String) {
        lock.lock(); defer { lock.unlock() }
        _bodies.append(body)
    }
    var bodies: [String] {
        lock.lock(); defer { lock.unlock() }
        return _bodies
    }

    static func readStream(_ stream: InputStream) -> String {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return String(data: data, encoding: .utf8) ?? ""
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

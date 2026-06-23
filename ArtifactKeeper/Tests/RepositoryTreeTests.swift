import Testing
import Foundation
@testable import ArtifactKeeper

// Covers the 1.2.1 browse cluster: repository tree (GET /api/v1/tree) and package
// versions (GET /api/v1/packages/{id}/versions). Path-pinning + decode tests using
// the per-session MockSession so they are safe under parallel execution.

private func treeOk(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
}

private final class TreePathLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func add(_ p: String) { lock.lock(); values.append(p); lock.unlock() }
    var paths: [String] { lock.lock(); defer { lock.unlock() }; return values }
}

@Suite("Repository Tree API Tests")
struct RepositoryTreeAPITests {

    @Test func getRepositoryTreeHitsTreePathWithRepoKey() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = TreePathLog()
        let queryLog = TreePathLog()
        mock.handler = { request in
            log.add(request.url!.path)
            queryLog.add(request.url!.query ?? "")
            return treeOk(request.url!, """
            {"nodes": [
              {"id": "n1", "name": "com", "path": "com", "type": "directory", "has_children": true,
               "children_count": 3, "size_bytes": null, "repository_key": "maven-local", "created_at": null},
              {"id": "n2", "name": "x.jar", "path": "com/x.jar", "type": "file", "has_children": false,
               "children_count": null, "size_bytes": 1024, "repository_key": "maven-local", "created_at": "2026-01-01T00:00:00Z"}
            ]}
            """)
        }

        let nodes = try await mock.client.getRepositoryTree(repoKey: "maven-local")

        #expect(log.paths.contains("/api/v1/tree"))
        #expect(queryLog.paths.first?.contains("repository_key=maven-local") == true)
        #expect(nodes.count == 2)
        #expect(nodes[0].isDirectory == true)
        #expect(nodes[1].isDirectory == false)
        #expect(nodes[1].sizeBytes == 1024)
    }

    @Test func getRepositoryTreeIncludesPathQueryWhenProvided() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let queryLog = TreePathLog()
        mock.handler = { request in
            queryLog.add(request.url!.query ?? "")
            return treeOk(request.url!, "{\"nodes\": []}")
        }

        _ = try await mock.client.getRepositoryTree(repoKey: "maven-local", path: "com/example")

        let query = queryLog.paths.first ?? ""
        #expect(query.contains("repository_key=maven-local"))
        #expect(query.contains("path=com/example") || query.contains("path=com%2Fexample"))
    }

    @Test func getRepositoryTreeOmitsPathQueryAtRoot() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let queryLog = TreePathLog()
        mock.handler = { request in
            queryLog.add(request.url!.query ?? "")
            return treeOk(request.url!, "{\"nodes\": []}")
        }

        _ = try await mock.client.getRepositoryTree(repoKey: "maven-local")

        #expect(queryLog.paths.first?.contains("path=") == false)
    }

    @Test func getPackageVersionsHitsVersionsPathAndDecodes() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = TreePathLog()
        mock.handler = { request in
            log.add(request.url!.path)
            return treeOk(request.url!, """
            {"versions": [
              {"version": "2.0.0", "size_bytes": 2048, "download_count": 50, "created_at": "2026-02-01T00:00:00Z", "checksum_sha256": "b"},
              {"version": "1.0.0", "size_bytes": 1024, "download_count": 10, "created_at": "2026-01-01T00:00:00Z", "checksum_sha256": "a"}
            ]}
            """)
        }

        let versions = try await mock.client.getPackageVersions(packageId: "pkg-7")

        #expect(log.paths.contains("/api/v1/packages/pkg-7/versions"))
        #expect(versions.count == 2)
        #expect(versions[0].version == "2.0.0")
        #expect(versions[0].downloadCount == 50)
        #expect(versions[1].sizeBytes == 1024)
    }
}

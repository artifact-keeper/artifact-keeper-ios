import Testing
import Foundation
@testable import ArtifactKeeper

// Covers the 1.2.1 Artifact Detail cluster: APIClient routing/decoding for
// detail, metadata, stats and the artifact-labels CRUD, plus the view-model
// load and label-mutation flows. Requests are stubbed via MockURLProtocol
// (defined in APIClientNetworkTests.swift) and the path is captured to assert
// the calls hit the 1.2.1 endpoints.

private func artifactOk(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
}

private func makeArtifactTestClient(baseURL: String = "https://test-api.example.com") -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    config.timeoutIntervalForRequest = 5
    let session = URLSession(configuration: config)
    return APIClient(baseURL: baseURL, session: session)
}

// Thread-safe path collector for assertions across multiple requests.
private final class ArtifactPathLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func add(_ p: String) { lock.lock(); values.append(p); lock.unlock() }
    var paths: [String] { lock.lock(); defer { lock.unlock() }; return values }
}

@Suite("Artifact Detail API Tests", .serialized)
struct ArtifactDetailAPITests {
    init() { MockURLProtocol.reset() }

    @Test func getArtifactDetailHitsArtifactPathAndDecodes() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            return artifactOk(request.url!, """
            {
              "id": "art-1", "repository_key": "maven-local", "path": "com/x/1.0/x.jar",
              "name": "x.jar", "version": "1.0", "content_type": "application/java-archive",
              "size_bytes": 2048, "checksum_sha256": "abc", "download_count": 7,
              "created_at": "2026-01-01T00:00:00Z", "cache_cached_at": null, "cache_expires_at": null
            }
            """)
        }

        let detail = try await client.getArtifactDetail(id: "art-1")

        #expect(log.paths.contains("/api/v1/artifacts/art-1"))
        #expect(detail.id == "art-1")
        #expect(detail.repositoryKey == "maven-local")
        #expect(detail.sizeBytes == 2048)
        #expect(detail.downloadCount == 7)
        #expect(detail.version == "1.0")
    }

    @Test func getArtifactMetadataHitsMetadataPath() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            return artifactOk(request.url!, """
            {"artifact_id": "art-1", "format": "maven", "metadata": {"group": "com.x"}, "properties": {"build": 42}}
            """)
        }

        let meta = try await client.getArtifactMetadata(id: "art-1")

        #expect(log.paths.contains("/api/v1/artifacts/art-1/metadata"))
        #expect(meta.format == "maven")
        #expect(meta.metadata?["group"]?.displayString == "com.x")
        #expect(meta.properties?["build"]?.displayString == "42")
    }

    @Test func getArtifactStatsHitsStatsPath() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            return artifactOk(request.url!, """
            {"artifact_id": "art-1", "download_count": 12, "first_downloaded": "2026-01-02T00:00:00Z", "last_downloaded": "2026-03-01T00:00:00Z"}
            """)
        }

        let stats = try await client.getArtifactStats(id: "art-1")

        #expect(log.paths.contains("/api/v1/artifacts/art-1/stats"))
        #expect(stats.downloadCount == 12)
        #expect(stats.lastDownloaded == "2026-03-01T00:00:00Z")
    }

    @Test func listArtifactLabelsHitsLabelsPathAndDecodes() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            return artifactOk(request.url!, """
            {"items": [{"id": "l1", "artifact_id": "art-1", "key": "env", "value": "prod", "created_at": "2026-01-01T00:00:00Z"}], "total": 1}
            """)
        }

        let labels = try await client.listArtifactLabels(id: "art-1")

        #expect(log.paths.contains("/api/v1/artifacts/art-1/labels"))
        #expect(labels.count == 1)
        #expect(labels[0].key == "env")
        #expect(labels[0].value == "prod")
    }

    @Test func addArtifactLabelPostsToKeyedPath() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            #expect(request.httpMethod == "POST")
            return artifactOk(request.url!, """
            {"id": "l2", "artifact_id": "art-1", "key": "team", "value": "platform", "created_at": "2026-01-01T00:00:00Z"}
            """, status: 201)
        }

        let label = try await client.addArtifactLabel(id: "art-1", key: "team", value: "platform")

        #expect(log.paths.contains("/api/v1/artifacts/art-1/labels/team"))
        #expect(label.key == "team")
        #expect(label.value == "platform")
    }

    @Test func setArtifactLabelsPutsToLabelsPath() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            #expect(request.httpMethod == "PUT")
            return artifactOk(request.url!, """
            {"items": [{"id": "l3", "artifact_id": "art-1", "key": "tier", "value": "gold", "created_at": "2026-01-01T00:00:00Z"}], "total": 1}
            """)
        }

        let labels = try await client.setArtifactLabels(id: "art-1", labels: [ArtifactLabelEntry(key: "tier", value: "gold")])

        #expect(log.paths.contains("/api/v1/artifacts/art-1/labels"))
        #expect(labels.first?.key == "tier")
    }

    @Test func deleteArtifactLabelDeletesKeyedPath() async throws {
        let client = makeArtifactTestClient()
        let log = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            log.add(request.url!.path)
            #expect(request.httpMethod == "DELETE")
            return artifactOk(request.url!, "")
        }

        try await client.deleteArtifactLabel(id: "art-1", key: "env")

        #expect(log.paths.contains("/api/v1/artifacts/art-1/labels/env"))
    }
}

@Suite("Artifact Detail ViewModel Tests", .serialized)
struct ArtifactDetailViewModelTests {
    init() { MockURLProtocol.reset() }

    @Test @MainActor func loadPopulatesDetailMetadataStatsAndLabels() async {
        let client = makeArtifactTestClient()
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            if path == "/api/v1/artifacts/art-9" {
                return artifactOk(request.url!, """
                {"id": "art-9", "repository_key": "npm-local", "path": "x/-/x-1.0.tgz", "name": "x-1.0.tgz",
                 "version": "1.0", "content_type": "application/gzip", "size_bytes": 100, "checksum_sha256": "h",
                 "download_count": 3, "created_at": "2026-01-01T00:00:00Z", "cache_cached_at": null, "cache_expires_at": null}
                """)
            }
            if path == "/api/v1/artifacts/art-9/metadata" {
                return artifactOk(request.url!, """
                {"artifact_id": "art-9", "format": "npm", "metadata": {}, "properties": {}}
                """)
            }
            if path == "/api/v1/artifacts/art-9/stats" {
                return artifactOk(request.url!, """
                {"artifact_id": "art-9", "download_count": 3, "first_downloaded": null, "last_downloaded": null}
                """)
            }
            // labels
            return artifactOk(request.url!, """
            {"items": [{"id": "l1", "artifact_id": "art-9", "key": "env", "value": "dev", "created_at": "2026-01-01T00:00:00Z"}], "total": 1}
            """)
        }

        let vm = ArtifactDetailViewModel(artifactId: "art-9", api: client)
        await vm.load()

        #expect(vm.detail?.id == "art-9")
        #expect(vm.metadata?.format == "npm")
        #expect(vm.stats?.downloadCount == 3)
        #expect(vm.labels.count == 1)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    @Test @MainActor func loadSetsErrorWhenDetailFails() async {
        let client = makeArtifactTestClient()
        MockURLProtocol.requestHandler = { request in
            return artifactOk(request.url!, "{\"error\":\"not found\"}", status: 404)
        }

        let vm = ArtifactDetailViewModel(artifactId: "missing", api: client)
        await vm.load()

        #expect(vm.detail == nil)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test @MainActor func addLabelReloadsLabelSet() async {
        let client = makeArtifactTestClient()
        let postCount = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            postCount.add(request.httpMethod ?? "")
            if request.httpMethod == "POST" {
                return artifactOk(request.url!, """
                {"id": "l2", "artifact_id": "art-1", "key": "team", "value": "platform", "created_at": "2026-01-01T00:00:00Z"}
                """, status: 201)
            }
            // subsequent GET reload returns two labels
            return artifactOk(request.url!, """
            {"items": [
              {"id": "l1", "artifact_id": "art-1", "key": "env", "value": "prod", "created_at": "2026-01-01T00:00:00Z"},
              {"id": "l2", "artifact_id": "art-1", "key": "team", "value": "platform", "created_at": "2026-01-01T00:00:00Z"}
            ], "total": 2}
            """)
        }

        let vm = ArtifactDetailViewModel(artifactId: "art-1", api: client)
        await vm.addLabel(key: "team", value: "platform")

        #expect(vm.labels.count == 2)
        #expect(vm.labelError == nil)
        #expect(postCount.paths.contains("POST"))
    }

    @Test @MainActor func addLabelIgnoresBlankKey() async {
        let client = makeArtifactTestClient()
        let called = ArtifactPathLog()
        MockURLProtocol.requestHandler = { request in
            called.add(request.url!.path)
            return artifactOk(request.url!, "{}")
        }

        let vm = ArtifactDetailViewModel(artifactId: "art-1", api: client)
        await vm.addLabel(key: "   ", value: "x")

        #expect(called.paths.isEmpty)
    }
}

import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

// Path-pinning tests for the SDK-backed curation methods on APIClient. Each
// drives the real production method through a RecordingTransport (defined in
// SecurityDispatchTests.swift, same target) with runtime ids and asserts the
// request path, method, and operation id. Single-object cases use `try?` since
// the canned empty object is recorded before it fails to decode.

@Suite("Curation SDK Dispatch Tests")
struct CurationDispatchTests {

    private func makeClient() async -> (APIClient, RecordingTransport) {
        let transport = RecordingTransport()
        let sdk = Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )
        let api = APIClient(baseURL: "https://example.test", session: .shared)
        await api.setSDKClientForTesting(sdk)
        return (api, transport)
    }

    private func path(_ p: String?) -> String {
        guard let p else { return "" }
        return String(p.split(separator: "?", maxSplits: 1)[0])
    }

    @Test func listCurationPackagesHitsPackagesPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listCurationPackages(stagingRepoId: "stg-1")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/curation/packages")
        #expect(rec?.operationID == "list_curation_packages")
    }

    @Test func getCurationPackageHitsPackageByIdPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getCurationPackage(id: "pkg-7")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/curation/packages/pkg-7")
        #expect(rec?.operationID == "get_curation_package")
    }

    @Test func approveCurationPackageHitsApprovePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.approveCurationPackage(id: "pkg-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/curation/packages/pkg-1/approve")
        #expect(rec?.operationID == "approve_package")
    }

    @Test func blockCurationPackageHitsBlockPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.blockCurationPackage(id: "pkg-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/curation/packages/pkg-1/block")
        #expect(rec?.operationID == "block_package")
    }

    @Test func getCurationStatsHitsStatsPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getCurationStats(stagingRepoId: "stg-1")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/curation/stats")
        #expect(rec?.operationID == "stats")
    }
}

import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

// Path-pinning tests for the SDK-backed migration methods on APIClient. Each
// test drives the real production method through a RecordingTransport (defined in
// SecurityDispatchTests.swift, same target) with a runtime job id and asserts the
// request path, method, and operation id. Single-object cases use `try?` since
// the canned empty object is recorded before it fails to decode.

@Suite("Migration SDK Dispatch Tests")
struct MigrationDispatchTests {

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

    @Test func listMigrationsHitsMigrationsPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listMigrations()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/migrations")
        #expect(rec?.operationID == "list_migrations")
    }

    @Test func getMigrationHitsMigrationByIdPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getMigration(id: "job-7")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/migrations/job-7")
        #expect(rec?.operationID == "get_migration")
    }

    @Test func startMigrationHitsStartPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.startMigration(id: "job-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/migrations/job-1/start")
        #expect(rec?.operationID == "start_migration")
    }

    @Test func pauseMigrationHitsPausePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.pauseMigration(id: "job-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/migrations/job-1/pause")
        #expect(rec?.operationID == "pause_migration")
    }

    @Test func resumeMigrationHitsResumePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.resumeMigration(id: "job-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/migrations/job-1/resume")
        #expect(rec?.operationID == "resume_migration")
    }

    @Test func cancelMigrationHitsCancelPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.cancelMigration(id: "job-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/migrations/job-1/cancel")
        #expect(rec?.operationID == "cancel_migration")
    }
}

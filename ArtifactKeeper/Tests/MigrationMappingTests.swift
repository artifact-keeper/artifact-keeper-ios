import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

@Suite("Migration SDK Mapping Tests")
struct MigrationMappingTests {

    private static let created = Date(timeIntervalSince1970: 1_700_000_000)
    private static let started = Date(timeIntervalSince1970: 1_700_000_100)

    @Test func migrationJobMapsAllFields() {
        let sdk = Components.Schemas.MigrationJobResponse(
            completed_items: 7,
            config: .init(),
            created_at: Self.created,
            error_summary: nil,
            estimated_time_remaining: 120,
            failed_items: 1,
            finished_at: nil,
            id: "job-1",
            job_type: "repository",
            progress_percent: 70.5,
            skipped_items: 2,
            source_connection_id: "conn-9",
            started_at: Self.started,
            status: "running",
            total_bytes: 2048,
            total_items: 10,
            transferred_bytes: 1024
        )

        let model = MigrationJob(from: sdk)

        #expect(model.id == "job-1")
        #expect(model.sourceConnectionId == "conn-9")
        #expect(model.status == "running")
        #expect(model.jobType == "repository")
        #expect(model.totalItems == 10)
        #expect(model.completedItems == 7)
        #expect(model.failedItems == 1)
        #expect(model.skippedItems == 2)
        #expect(model.totalBytes == 2048)
        #expect(model.transferredBytes == 1024)
        #expect(model.progressPercent == 70.5)
        #expect(model.errorSummary == nil)
        #expect(model.estimatedTimeRemaining == 120)
        #expect(model.startedAt == SecurityMapping.isoString(Self.started))
        #expect(model.finishedAt == nil)
        #expect(model.createdAt == SecurityMapping.isoString(Self.created))
    }
}

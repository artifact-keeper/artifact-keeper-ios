import Foundation
import ArtifactKeeperClient

// MARK: - SDK -> App Model Mapping (Migrations)
//
// Mirrors the other mapping files: snake_case Int32/Int64/Date fields from the
// generated client map to the camelCase MigrationJob with Int/Int64 and ISO8601
// date strings.

extension MigrationJob {
    init(from sdk: Components.Schemas.MigrationJobResponse) {
        self.init(
            id: sdk.id,
            sourceConnectionId: sdk.source_connection_id,
            status: sdk.status,
            jobType: sdk.job_type,
            totalItems: Int(sdk.total_items),
            completedItems: Int(sdk.completed_items),
            failedItems: Int(sdk.failed_items),
            skippedItems: Int(sdk.skipped_items),
            totalBytes: sdk.total_bytes,
            transferredBytes: sdk.transferred_bytes,
            progressPercent: sdk.progress_percent,
            errorSummary: sdk.error_summary,
            estimatedTimeRemaining: sdk.estimated_time_remaining,
            startedAt: sdk.started_at.map(SecurityMapping.isoString),
            finishedAt: sdk.finished_at.map(SecurityMapping.isoString),
            createdAt: SecurityMapping.isoString(sdk.created_at)
        )
    }
}

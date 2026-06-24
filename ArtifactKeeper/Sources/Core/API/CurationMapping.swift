import Foundation
import ArtifactKeeperClient

// MARK: - SDK -> App Model Mapping (Curation)
//
// Mirrors the other mapping files: snake_case Int64/Date fields from the
// generated client map to the camelCase CurationPackage / CurationStats with
// Int64 and ISO8601 date strings.

extension CurationPackage {
    init(from sdk: Components.Schemas.PackageResponse) {
        self.init(
            id: sdk.id,
            repositoryKey: sdk.repository_key,
            name: sdk.name,
            version: sdk.version,
            format: sdk.format,
            description: sdk.description,
            sizeBytes: sdk.size_bytes,
            downloadCount: sdk.download_count,
            createdAt: SecurityMapping.isoString(sdk.created_at),
            updatedAt: SecurityMapping.isoString(sdk.updated_at)
        )
    }
}

extension CurationStatusCount {
    init(from sdk: Components.Schemas.StatusCount) {
        self.init(status: sdk.status, count: sdk.count)
    }
}

extension CurationStats {
    init(from sdk: Components.Schemas.StatsResponse) {
        self.init(
            stagingRepoId: sdk.staging_repo_id,
            counts: sdk.counts.map { CurationStatusCount(from: $0) }
        )
    }
}

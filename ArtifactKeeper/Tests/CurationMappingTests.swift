import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

@Suite("Curation SDK Mapping Tests")
struct CurationMappingTests {

    private static let created = Date(timeIntervalSince1970: 1_700_000_000)
    private static let updated = Date(timeIntervalSince1970: 1_700_086_400)

    @Test func curationPackageMapsAllFields() {
        let sdk = Components.Schemas.PackageResponse(
            created_at: Self.created,
            description: "test package",
            download_count: 42,
            format: "npm",
            id: "pkg-1",
            metadata: .init(),
            name: "left-pad",
            repository_key: "npm-staging",
            size_bytes: 2048,
            updated_at: Self.updated,
            version: "1.3.0"
        )

        let model = CurationPackage(from: sdk)

        #expect(model.id == "pkg-1")
        #expect(model.repositoryKey == "npm-staging")
        #expect(model.name == "left-pad")
        #expect(model.version == "1.3.0")
        #expect(model.format == "npm")
        #expect(model.description == "test package")
        #expect(model.sizeBytes == 2048)
        #expect(model.downloadCount == 42)
        #expect(model.createdAt == SecurityMapping.isoString(Self.created))
        #expect(model.updatedAt == SecurityMapping.isoString(Self.updated))
    }

    @Test func curationStatsMaps() {
        let sdk = Components.Schemas.StatsResponse(
            counts: [
                Components.Schemas.StatusCount(count: 12, status: "pending"),
                Components.Schemas.StatusCount(count: 3, status: "blocked"),
            ],
            staging_repo_id: "stg-1"
        )

        let model = CurationStats(from: sdk)

        #expect(model.stagingRepoId == "stg-1")
        #expect(model.counts.count == 2)
        #expect(model.counts.first?.status == "pending")
        #expect(model.counts.first?.count == 12)
        #expect(model.counts.first?.id == "pending")
    }
}

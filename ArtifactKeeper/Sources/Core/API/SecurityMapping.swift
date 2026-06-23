import Foundation
import ArtifactKeeperClient

// MARK: - SDK -> App Model Mapping (Security / SBOM)
//
// The generated ArtifactKeeperClient returns strongly typed responses with snake_case
// fields, Int32 counts and Foundation.Date timestamps. The app's view layer works with
// the hand-written models in Core/Models (ScanResult, ScanFinding, SbomComponent, ...),
// which use camelCase, Int counts and ISO8601 date strings. These initializers are the
// single mapping point between the two so the conversions stay testable in isolation.

extension ScanResult {
    init(from sdk: Components.Schemas.ScanResponse) {
        self.init(
            id: sdk.id,
            artifactId: sdk.artifact_id,
            scanType: sdk.scan_type,
            status: sdk.status,
            findingsCount: Int(sdk.findings_count),
            criticalCount: Int(sdk.critical_count),
            highCount: Int(sdk.high_count),
            mediumCount: Int(sdk.medium_count),
            lowCount: Int(sdk.low_count),
            startedAt: sdk.started_at.map(SecurityMapping.isoString),
            completedAt: sdk.completed_at.map(SecurityMapping.isoString),
            errorMessage: sdk.error_message,
            artifactName: sdk.artifact_name,
            artifactVersion: sdk.artifact_version
        )
    }
}

extension ScanFinding {
    init(from sdk: Components.Schemas.FindingResponse) {
        self.init(
            id: sdk.id,
            scanResultId: sdk.scan_result_id,
            artifactId: sdk.artifact_id,
            severity: sdk.severity,
            title: sdk.title,
            description: sdk.description,
            cveId: sdk.cve_id,
            affectedComponent: sdk.affected_component,
            affectedVersion: sdk.affected_version,
            fixedVersion: sdk.fixed_version,
            source: sdk.source,
            sourceUrl: sdk.source_url,
            isAcknowledged: sdk.is_acknowledged,
            acknowledgedBy: sdk.acknowledged_by,
            acknowledgedReason: sdk.acknowledged_reason,
            acknowledgedAt: sdk.acknowledged_at.map(SecurityMapping.isoString),
            createdAt: SecurityMapping.isoString(sdk.created_at)
        )
    }
}

extension SbomComponent {
    init(from sdk: Components.Schemas.ComponentResponse) {
        self.init(
            id: sdk.id,
            sbomId: sdk.sbom_id,
            name: sdk.name,
            version: sdk.version,
            purl: sdk.purl,
            cpe: sdk.cpe,
            componentType: sdk.component_type,
            licenses: sdk.licenses,
            sha256: sdk.sha256,
            sha1: sdk.sha1,
            md5: sdk.md5,
            supplier: sdk.supplier,
            author: sdk.author
        )
    }
}

/// SBOM summary mapped from the `SbomResponse` half of a `SbomContentResponse`.
/// The view only needs the metadata (counts, format, licenses, generation info),
/// not the raw document payload, so this carries the summary fields.
struct SbomSummary: Identifiable, Sendable, Equatable {
    let id: String
    let artifactId: String
    let repositoryId: String
    let format: String
    let formatVersion: String
    let specVersion: String?
    let componentCount: Int
    let dependencyCount: Int
    let licenseCount: Int
    let licenses: [String]
    let generator: String?
    let generatorVersion: String?
    let generatedAt: String

    init(from sdk: Components.Schemas.SbomResponse) {
        self.id = sdk.id
        self.artifactId = sdk.artifact_id
        self.repositoryId = sdk.repository_id
        self.format = sdk.format
        self.formatVersion = sdk.format_version
        self.specVersion = sdk.spec_version
        self.componentCount = Int(sdk.component_count)
        self.dependencyCount = Int(sdk.dependency_count)
        self.licenseCount = Int(sdk.license_count)
        self.licenses = sdk.licenses
        self.generator = sdk.generator
        self.generatorVersion = sdk.generator_version
        self.generatedAt = SecurityMapping.isoString(sdk.generated_at)
    }
}

extension SbomSummary {
    /// A `SbomContentResponse` is the SBOM metadata (`value1`) plus the raw document
    /// payload (`value2`). The summary view only needs the metadata half.
    init(from sdk: Components.Schemas.SbomContentResponse) {
        self.init(from: sdk.value1)
    }
}

// MARK: - Date Formatting

enum SecurityMapping {
    /// Render a `Foundation.Date` as an ISO8601 string with fractional seconds so it
    /// round-trips through the existing string-based view formatters unchanged.
    static func isoString(_ date: Foundation.Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

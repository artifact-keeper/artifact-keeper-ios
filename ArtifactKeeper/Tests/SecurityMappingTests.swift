import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

// Tests for the SDK -> app model mapping that backs the artifact-scoped Scan Results
// and SBOM screens. These exercise the conversion in isolation (no live client), so a
// drift in the generated SDK field shapes surfaces here rather than at runtime.

@Suite("Security SDK Mapping Tests")
struct SecurityMappingTests {

    // A fixed instant used across the fixtures so the ISO8601 round-trip is assertable.
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private static var fixedIso: String { SecurityMapping.isoString(fixedDate) }

    // MARK: - ScanResult

    @Test func scanResultMapsAllFields() {
        let sdk = Components.Schemas.ScanResponse(
            artifact_id: "art-1",
            artifact_name: "libfoo",
            artifact_version: "1.2.3",
            completed_at: Self.fixedDate,
            created_at: Self.fixedDate,
            critical_count: 2,
            error_message: nil,
            findings_count: 7,
            high_count: 3,
            id: "scan-1",
            info_count: 0,
            is_reused: false,
            low_count: 1,
            medium_count: 1,
            repository_id: "repo-1",
            scan_type: "vulnerability",
            scanner_version: "trivy-0.69",
            started_at: Self.fixedDate,
            status: "completed"
        )

        let model = ScanResult(from: sdk)

        #expect(model.id == "scan-1")
        #expect(model.artifactId == "art-1")
        #expect(model.artifactName == "libfoo")
        #expect(model.artifactVersion == "1.2.3")
        #expect(model.scanType == "vulnerability")
        #expect(model.status == "completed")
        #expect(model.findingsCount == 7)
        #expect(model.criticalCount == 2)
        #expect(model.highCount == 3)
        #expect(model.mediumCount == 1)
        #expect(model.lowCount == 1)
        #expect(model.completedAt == Self.fixedIso)
        #expect(model.startedAt == Self.fixedIso)
        #expect(model.errorMessage == nil)
    }

    @Test func scanResultMapsNilOptionals() {
        let sdk = Components.Schemas.ScanResponse(
            artifact_id: "art-2",
            artifact_name: nil,
            artifact_version: nil,
            completed_at: nil,
            created_at: Self.fixedDate,
            critical_count: 0,
            error_message: "scanner timed out",
            findings_count: 0,
            high_count: 0,
            id: "scan-2",
            info_count: 0,
            is_reused: false,
            low_count: 0,
            medium_count: 0,
            repository_id: "repo-2",
            scan_type: "license",
            scanner_version: nil,
            started_at: nil,
            status: "failed"
        )

        let model = ScanResult(from: sdk)

        #expect(model.artifactName == nil)
        #expect(model.artifactVersion == nil)
        #expect(model.completedAt == nil)
        #expect(model.startedAt == nil)
        #expect(model.errorMessage == "scanner timed out")
        #expect(model.status == "failed")
    }

    // MARK: - ScanFinding

    @Test func scanFindingMapsAllFields() {
        let sdk = Components.Schemas.FindingResponse(
            acknowledged_at: Self.fixedDate,
            acknowledged_by: "alice",
            acknowledged_reason: "false positive",
            affected_component: "openssl",
            affected_version: "3.0.1",
            artifact_id: "art-1",
            created_at: Self.fixedDate,
            cve_id: "CVE-2024-0001",
            description: "A vulnerability",
            fixed_version: "3.0.2",
            id: "find-1",
            is_acknowledged: true,
            scan_result_id: "scan-1",
            severity: "critical",
            source: "trivy",
            source_url: "https://example.com/cve",
            title: "OpenSSL flaw"
        )

        let model = ScanFinding(from: sdk)

        #expect(model.id == "find-1")
        #expect(model.scanResultId == "scan-1")
        #expect(model.artifactId == "art-1")
        #expect(model.severity == "critical")
        #expect(model.title == "OpenSSL flaw")
        #expect(model.description == "A vulnerability")
        #expect(model.cveId == "CVE-2024-0001")
        #expect(model.affectedComponent == "openssl")
        #expect(model.affectedVersion == "3.0.1")
        #expect(model.fixedVersion == "3.0.2")
        #expect(model.source == "trivy")
        #expect(model.sourceUrl == "https://example.com/cve")
        #expect(model.isAcknowledged == true)
        #expect(model.acknowledgedBy == "alice")
        #expect(model.acknowledgedReason == "false positive")
        #expect(model.acknowledgedAt == Self.fixedIso)
        #expect(model.createdAt == Self.fixedIso)
    }

    @Test func scanFindingMapsUnacknowledged() {
        let sdk = Components.Schemas.FindingResponse(
            acknowledged_at: nil,
            acknowledged_by: nil,
            acknowledged_reason: nil,
            affected_component: nil,
            affected_version: nil,
            artifact_id: "art-3",
            created_at: Self.fixedDate,
            cve_id: nil,
            description: nil,
            fixed_version: nil,
            id: "find-2",
            is_acknowledged: false,
            scan_result_id: "scan-3",
            severity: "low",
            source: nil,
            source_url: nil,
            title: "Minor issue"
        )

        let model = ScanFinding(from: sdk)

        #expect(model.isAcknowledged == false)
        #expect(model.acknowledgedAt == nil)
        #expect(model.cveId == nil)
        #expect(model.affectedComponent == nil)
        #expect(model.severity == "low")
    }

    // MARK: - SbomComponent

    @Test func sbomComponentMapsAllFields() {
        let sdk = Components.Schemas.ComponentResponse(
            author: "Foo Inc",
            component_type: "library",
            cpe: "cpe:2.3:a:foo",
            id: "comp-1",
            licenses: ["MIT", "Apache-2.0"],
            md5: "md5hash",
            name: "libfoo",
            purl: "pkg:cargo/libfoo@1.0",
            sbom_id: "sbom-1",
            sha1: "sha1hash",
            sha256: "sha256hash",
            supplier: "vendor",
            version: "1.0.0"
        )

        let model = SbomComponent(from: sdk)

        #expect(model.id == "comp-1")
        #expect(model.sbomId == "sbom-1")
        #expect(model.name == "libfoo")
        #expect(model.version == "1.0.0")
        #expect(model.purl == "pkg:cargo/libfoo@1.0")
        #expect(model.cpe == "cpe:2.3:a:foo")
        #expect(model.componentType == "library")
        #expect(model.licenses == ["MIT", "Apache-2.0"])
        #expect(model.sha256 == "sha256hash")
        #expect(model.sha1 == "sha1hash")
        #expect(model.md5 == "md5hash")
        #expect(model.supplier == "vendor")
        #expect(model.author == "Foo Inc")
    }

    // MARK: - SbomSummary

    @Test func sbomSummaryMapsFromResponse() {
        let sdk = Components.Schemas.SbomResponse(
            artifact_id: "art-1",
            component_count: 42,
            content_hash: "hash",
            created_at: Self.fixedDate,
            dependency_count: 40,
            format: "cyclonedx",
            format_version: "1.5",
            generated_at: Self.fixedDate,
            generator: "syft",
            generator_version: "1.0",
            id: "sbom-1",
            license_count: 5,
            licenses: ["MIT"],
            repository_id: "repo-1",
            spec_version: "1.5"
        )

        let model = SbomSummary(from: sdk)

        #expect(model.id == "sbom-1")
        #expect(model.artifactId == "art-1")
        #expect(model.repositoryId == "repo-1")
        #expect(model.format == "cyclonedx")
        #expect(model.formatVersion == "1.5")
        #expect(model.specVersion == "1.5")
        #expect(model.componentCount == 42)
        #expect(model.dependencyCount == 40)
        #expect(model.licenseCount == 5)
        #expect(model.licenses == ["MIT"])
        #expect(model.generator == "syft")
        #expect(model.generatorVersion == "1.0")
        #expect(model.generatedAt == Self.fixedIso)
    }

    // MARK: - SecurityDashboard

    @Test func securityDashboardMapsAllFields() {
        let sdk = Components.Schemas.DashboardResponse(
            critical_findings: 4,
            high_findings: 9,
            policy_violations_blocked: 2,
            repos_grade_a: 5,
            repos_grade_f: 1,
            repos_with_scanning: 8,
            total_findings: 30,
            total_scans: 100
        )

        let model = SecurityDashboard(from: sdk)

        #expect(model.criticalFindings == 4)
        #expect(model.highFindings == 9)
        #expect(model.policyViolationsBlocked == 2)
        #expect(model.reposGradeA == 5)
        #expect(model.reposGradeF == 1)
        #expect(model.reposWithScanning == 8)
        #expect(model.totalFindings == 30)
        #expect(model.totalScans == 100)
    }

    // MARK: - RepoSecurityScore (from ScoreResponse)

    @Test func securityScoreMapsAllFields() {
        let sdk = Components.Schemas.ScoreResponse(
            acknowledged_count: 3,
            calculated_at: Self.fixedDate,
            critical_count: 1,
            grade: "B",
            high_count: 2,
            id: "score-1",
            last_scan_at: Self.fixedDate,
            low_count: 4,
            medium_count: 5,
            repository_id: "repo-1",
            score: 82,
            total_findings: 12
        )

        let model = RepoSecurityScore(from: sdk)

        #expect(model.id == "score-1")
        #expect(model.repositoryId == "repo-1")
        #expect(model.grade == "B")
        #expect(model.score == 82)
        #expect(model.criticalCount == 1)
        #expect(model.highCount == 2)
        #expect(model.mediumCount == 5)
        #expect(model.lowCount == 4)
        #expect(model.totalFindings == 12)
        #expect(model.acknowledgedCount == 3)
        #expect(model.lastScanAt == Self.fixedIso)
        #expect(model.calculatedAt == Self.fixedIso)
    }

    @Test func securityScoreMapsNilLastScan() {
        let sdk = Components.Schemas.ScoreResponse(
            acknowledged_count: 0,
            calculated_at: Self.fixedDate,
            critical_count: 0,
            grade: "A",
            high_count: 0,
            id: "score-2",
            last_scan_at: nil,
            low_count: 0,
            medium_count: 0,
            repository_id: "repo-2",
            score: 100,
            total_findings: 0
        )

        let model = RepoSecurityScore(from: sdk)

        #expect(model.lastScanAt == nil)
        #expect(model.grade == "A")
        #expect(model.score == 100)
    }

    // MARK: - TriggerScanResult

    @Test func triggerScanResultMaps() {
        let sdk = Components.Schemas.TriggerScanResponse(
            artifacts_queued: 7,
            message: "Queued 7 artifacts for scanning"
        )

        let model = TriggerScanResult(from: sdk)

        #expect(model.artifactsQueued == 7)
        #expect(model.message == "Queued 7 artifacts for scanning")
    }

    // MARK: - ScanConfig

    @Test func scanConfigMaps() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_086_400)
        let sdk = Components.Schemas.ScanConfigResponse(
            block_on_policy_violation: true,
            created_at: created,
            id: "cfg-1",
            repository_id: "repo-9",
            scan_enabled: true,
            scan_on_proxy: false,
            scan_on_upload: true,
            severity_threshold: "high",
            updated_at: updated
        )

        let model = ScanConfig(from: sdk)

        #expect(model.id == "cfg-1")
        #expect(model.repositoryId == "repo-9")
        #expect(model.scanEnabled)
        #expect(model.scanOnUpload)
        #expect(!model.scanOnProxy)
        #expect(model.blockOnPolicyViolation)
        #expect(model.severityThreshold == "high")
        #expect(model.createdAt == SecurityMapping.isoString(created))
        #expect(model.updatedAt == SecurityMapping.isoString(updated))
    }
}

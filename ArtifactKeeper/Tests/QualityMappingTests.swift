import Testing
import Foundation
import OpenAPIRuntime
import ArtifactKeeperClient
@testable import ArtifactKeeper

// Tests for the SDK -> app model mapping behind the Quality Gates and Health
// dashboard screens. They exercise the conversion in isolation so generated SDK
// field drift surfaces here rather than at runtime.

@Suite("Quality SDK Mapping Tests")
struct QualityMappingTests {

    private static let created = Date(timeIntervalSince1970: 1_700_000_000)
    private static let updated = Date(timeIntervalSince1970: 1_700_086_400)

    @Test func qualityGateMapsAllFields() {
        let sdk = Components.Schemas.GateResponse(
            action: "block",
            created_at: Self.created,
            description: "Block risky artifacts",
            enforce_on_download: true,
            enforce_on_promotion: false,
            id: "gate-1",
            is_enabled: true,
            max_critical_issues: 0,
            max_high_issues: 2,
            max_medium_issues: nil,
            min_health_score: 80,
            min_metadata_score: nil,
            min_quality_score: 70,
            min_security_score: 90,
            name: "Production Gate",
            repository_id: "repo-9",
            required_checks: ["security", "metadata"],
            updated_at: Self.updated
        )

        let model = QualityGate(from: sdk)

        #expect(model.id == "gate-1")
        #expect(model.name == "Production Gate")
        #expect(model.description == "Block risky artifacts")
        #expect(model.repositoryId == "repo-9")
        #expect(model.action == "block")
        #expect(model.isEnabled)
        #expect(model.enforceOnDownload)
        #expect(!model.enforceOnPromotion)
        #expect(model.requiredChecks == ["security", "metadata"])
        #expect(model.minHealthScore == 80)
        #expect(model.minQualityScore == 70)
        #expect(model.minSecurityScore == 90)
        #expect(model.minMetadataScore == nil)
        #expect(model.maxCriticalIssues == 0)
        #expect(model.maxHighIssues == 2)
        #expect(model.maxMediumIssues == nil)
        #expect(model.createdAt == SecurityMapping.isoString(Self.created))
        #expect(model.updatedAt == SecurityMapping.isoString(Self.updated))
    }

    @Test func gateViolationMaps() {
        let sdk = Components.Schemas.GateViolationResponse(
            actual: "3",
            expected: "0",
            message: "Too many critical issues",
            rule: "max_critical_issues"
        )

        let model = GateViolation(from: sdk)

        #expect(model.rule == "max_critical_issues")
        #expect(model.expected == "0")
        #expect(model.actual == "3")
        #expect(model.message == "Too many critical issues")
        #expect(model.id == "max_critical_issues")
    }

    @Test func gateEvaluationMapsAndExtractsNumericScores() throws {
        let scores = try OpenAPIObjectContainer(unvalidatedValue: [
            "security": 90,
            "quality": 75,
            "label": "ignored-non-numeric"
        ])
        let sdk = Components.Schemas.GateEvaluationResponse(
            action: "warn",
            component_scores: scores,
            gate_name: "Production Gate",
            health_grade: "B",
            health_score: 82,
            passed: false,
            violations: [
                Components.Schemas.GateViolationResponse(
                    actual: "3", expected: "0", message: "criticals", rule: "max_critical_issues"
                )
            ]
        )

        let model = GateEvaluation(from: sdk)

        #expect(!model.passed)
        #expect(model.action == "warn")
        #expect(model.gateName == "Production Gate")
        #expect(model.healthScore == 82)
        #expect(model.healthGrade == "B")
        #expect(model.violations.count == 1)
        #expect(model.componentScores["security"] == 90)
        #expect(model.componentScores["quality"] == 75)
        // Non-numeric values are dropped.
        #expect(model.componentScores["label"] == nil)
    }

    @Test func healthDashboardMaps() throws {
        let repo = Components.Schemas.RepoHealthResponse(
            artifacts_evaluated: 10,
            artifacts_failing: 3,
            artifacts_passing: 7,
            avg_license_score: 88,
            avg_metadata_score: 70,
            avg_quality_score: 75,
            avg_security_score: 90,
            health_grade: "B",
            health_score: 80,
            last_evaluated_at: Self.updated,
            repository_id: "repo-1",
            repository_key: "maven-prod"
        )
        let sdk = Components.Schemas.HealthDashboardResponse(
            avg_health_score: 78,
            repos_grade_a: 5,
            repos_grade_b: 4,
            repos_grade_c: 3,
            repos_grade_d: 2,
            repos_grade_f: 1,
            repositories: [repo],
            total_artifacts_evaluated: 120,
            total_repositories: 15
        )

        let model = HealthDashboard(from: sdk)

        #expect(model.totalRepositories == 15)
        #expect(model.totalArtifactsEvaluated == 120)
        #expect(model.avgHealthScore == 78)
        #expect(model.reposGradeA == 5)
        #expect(model.reposGradeF == 1)
        #expect(model.repositories.count == 1)

        let mappedRepo = try #require(model.repositories.first)
        #expect(mappedRepo.repositoryKey == "maven-prod")
        #expect(mappedRepo.healthGrade == "B")
        #expect(mappedRepo.healthScore == 80)
        #expect(mappedRepo.artifactsPassing == 7)
        #expect(mappedRepo.artifactsFailing == 3)
        #expect(mappedRepo.avgSecurityScore == 90)
        #expect(mappedRepo.lastEvaluatedAt == SecurityMapping.isoString(Self.updated))
    }

    @Test func repoHealthMaps() {
        let sdk = Components.Schemas.RepoHealthResponse(
            artifacts_evaluated: 12,
            artifacts_failing: 4,
            artifacts_passing: 8,
            avg_license_score: 81,
            avg_metadata_score: 72,
            avg_quality_score: 77,
            avg_security_score: 95,
            health_grade: "A",
            health_score: 91,
            last_evaluated_at: Self.updated,
            repository_id: "repo-7",
            repository_key: "npm-prod"
        )

        let model = RepoHealth(from: sdk)

        #expect(model.repositoryId == "repo-7")
        #expect(model.repositoryKey == "npm-prod")
        #expect(model.healthGrade == "A")
        #expect(model.healthScore == 91)
        #expect(model.artifactsEvaluated == 12)
        #expect(model.artifactsPassing == 8)
        #expect(model.artifactsFailing == 4)
        #expect(model.avgSecurityScore == 95)
        #expect(model.avgLicenseScore == 81)
        #expect(model.lastEvaluatedAt == SecurityMapping.isoString(Self.updated))
    }

    @Test func checkSummaryMaps() {
        let sdk = Components.Schemas.CheckSummary(
            check_type: "security",
            completed_at: Self.updated,
            issues_count: 2,
            passed: false,
            score: 60,
            status: "completed"
        )

        let model = CheckSummary(from: sdk)

        #expect(model.checkType == "security")
        #expect(model.status == "completed")
        #expect(model.issuesCount == 2)
        #expect(model.passed == false)
        #expect(model.score == 60)
        #expect(model.completedAt == SecurityMapping.isoString(Self.updated))
        #expect(model.id == "security")
    }

    @Test func artifactHealthMaps() throws {
        let sdk = Components.Schemas.ArtifactHealthResponse(
            artifact_id: "art-1",
            checks: [
                Components.Schemas.CheckSummary(
                    check_type: "metadata", completed_at: nil, issues_count: 0,
                    passed: true, score: 100, status: "completed"
                )
            ],
            checks_passed: 3,
            checks_total: 4,
            critical_issues: 1,
            health_grade: "B",
            health_score: 82,
            last_checked_at: Self.updated,
            license_score: 90,
            metadata_score: 100,
            quality_score: 70,
            security_score: 85,
            total_issues: 5
        )

        let model = ArtifactHealth(from: sdk)

        #expect(model.artifactId == "art-1")
        #expect(model.healthScore == 82)
        #expect(model.healthGrade == "B")
        #expect(model.totalIssues == 5)
        #expect(model.criticalIssues == 1)
        #expect(model.checksPassed == 3)
        #expect(model.checksTotal == 4)
        #expect(model.securityScore == 85)
        #expect(model.qualityScore == 70)
        #expect(model.metadataScore == 100)
        #expect(model.licenseScore == 90)
        #expect(model.lastCheckedAt == SecurityMapping.isoString(Self.updated))
        #expect(model.checks.count == 1)

        let check = try #require(model.checks.first)
        #expect(check.checkType == "metadata")
        #expect(check.passed == true)
        #expect(check.completedAt == nil)
    }
}

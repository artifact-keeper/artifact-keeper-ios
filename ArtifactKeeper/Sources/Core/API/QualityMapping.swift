import Foundation
import ArtifactKeeperClient
import OpenAPIRuntime

// MARK: - SDK -> App Model Mapping (Quality Gates & Health)
//
// Mirrors SecurityMapping: the generated client returns snake_case fields, Int32
// counts and Foundation.Date timestamps; the view layer uses the camelCase models
// in Core/Models/Quality.swift with Int and ISO8601 date strings. Keeping the
// conversions here makes them testable without a live server.

extension QualityGate {
    init(from sdk: Components.Schemas.GateResponse) {
        self.init(
            id: sdk.id,
            name: sdk.name,
            description: sdk.description,
            repositoryId: sdk.repository_id,
            action: sdk.action,
            isEnabled: sdk.is_enabled,
            enforceOnPromotion: sdk.enforce_on_promotion,
            enforceOnDownload: sdk.enforce_on_download,
            requiredChecks: sdk.required_checks,
            minHealthScore: sdk.min_health_score.map(Int.init),
            minQualityScore: sdk.min_quality_score.map(Int.init),
            minSecurityScore: sdk.min_security_score.map(Int.init),
            minMetadataScore: sdk.min_metadata_score.map(Int.init),
            maxCriticalIssues: sdk.max_critical_issues.map(Int.init),
            maxHighIssues: sdk.max_high_issues.map(Int.init),
            maxMediumIssues: sdk.max_medium_issues.map(Int.init),
            createdAt: SecurityMapping.isoString(sdk.created_at),
            updatedAt: SecurityMapping.isoString(sdk.updated_at)
        )
    }
}

extension GateViolation {
    init(from sdk: Components.Schemas.GateViolationResponse) {
        self.init(
            rule: sdk.rule,
            expected: sdk.expected,
            actual: sdk.actual,
            message: sdk.message
        )
    }
}

extension GateEvaluation {
    init(from sdk: Components.Schemas.GateEvaluationResponse) {
        self.init(
            passed: sdk.passed,
            action: sdk.action,
            gateName: sdk.gate_name,
            healthScore: Int(sdk.health_score),
            healthGrade: sdk.health_grade,
            violations: sdk.violations.map { GateViolation(from: $0) },
            componentScores: QualityMapping.numericScores(sdk.component_scores)
        )
    }
}

extension RepoHealth {
    init(from sdk: Components.Schemas.RepoHealthResponse) {
        self.init(
            repositoryId: sdk.repository_id,
            repositoryKey: sdk.repository_key,
            healthScore: Int(sdk.health_score),
            healthGrade: sdk.health_grade,
            artifactsEvaluated: Int(sdk.artifacts_evaluated),
            artifactsPassing: Int(sdk.artifacts_passing),
            artifactsFailing: Int(sdk.artifacts_failing),
            avgSecurityScore: sdk.avg_security_score.map(Int.init),
            avgQualityScore: sdk.avg_quality_score.map(Int.init),
            avgMetadataScore: sdk.avg_metadata_score.map(Int.init),
            avgLicenseScore: sdk.avg_license_score.map(Int.init),
            lastEvaluatedAt: sdk.last_evaluated_at.map(SecurityMapping.isoString)
        )
    }
}

extension HealthDashboard {
    init(from sdk: Components.Schemas.HealthDashboardResponse) {
        self.init(
            totalRepositories: Int(sdk.total_repositories),
            totalArtifactsEvaluated: Int(sdk.total_artifacts_evaluated),
            avgHealthScore: Int(sdk.avg_health_score),
            reposGradeA: Int(sdk.repos_grade_a),
            reposGradeB: Int(sdk.repos_grade_b),
            reposGradeC: Int(sdk.repos_grade_c),
            reposGradeD: Int(sdk.repos_grade_d),
            reposGradeF: Int(sdk.repos_grade_f),
            repositories: sdk.repositories.map { RepoHealth(from: $0) }
        )
    }
}

// MARK: - Helpers

enum QualityMapping {
    /// Extract integer component scores from the free-form `component_scores`
    /// object. The backend returns numeric scores keyed by component name
    /// (security, quality, metadata, ...). Non-numeric values are dropped.
    static func numericScores(_ container: OpenAPIObjectContainer) -> [String: Int] {
        var result: [String: Int] = [:]
        for (key, value) in container.value {
            if let intValue = value as? Int {
                result[key] = intValue
            } else if let doubleValue = value as? Double {
                result[key] = Int(doubleValue)
            } else if let stringValue = value as? String, let parsed = Int(stringValue) {
                result[key] = parsed
            }
        }
        return result
    }
}

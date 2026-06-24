import Foundation

// MARK: - Quality Gates & Health (1.2.1 /api/v1/quality/*)

/// A quality gate definition (GET /api/v1/quality/gates, GET /api/v1/quality/gates/{id}).
struct QualityGate: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let description: String?
    let repositoryId: String?
    let action: String
    let isEnabled: Bool
    let enforceOnPromotion: Bool
    let enforceOnDownload: Bool
    let requiredChecks: [String]
    let minHealthScore: Int?
    let minQualityScore: Int?
    let minSecurityScore: Int?
    let minMetadataScore: Int?
    let maxCriticalIssues: Int?
    let maxHighIssues: Int?
    let maxMediumIssues: Int?
    let createdAt: String
    let updatedAt: String
}

/// A single rule violation from a gate evaluation.
struct GateViolation: Codable, Identifiable, Sendable, Equatable {
    let rule: String
    let expected: String
    let actual: String
    let message: String

    // Violations have no server-side id; derive a stable one from the rule.
    var id: String { rule }
}

/// The result of evaluating a gate against an artifact
/// (POST /api/v1/quality/gates/evaluate/{artifact_id}).
struct GateEvaluation: Sendable, Equatable {
    let passed: Bool
    let action: String
    let gateName: String
    let healthScore: Int
    let healthGrade: String
    let violations: [GateViolation]
    /// Component score breakdown (e.g. security, quality, metadata). Numeric values
    /// are extracted from the free-form `component_scores` object; non-numeric
    /// entries are dropped.
    let componentScores: [String: Int]
}

/// Per-repository health summary inside the health dashboard.
struct RepoHealth: Codable, Identifiable, Sendable, Equatable {
    let repositoryId: String
    let repositoryKey: String
    let healthScore: Int
    let healthGrade: String
    let artifactsEvaluated: Int
    let artifactsPassing: Int
    let artifactsFailing: Int
    let avgSecurityScore: Int?
    let avgQualityScore: Int?
    let avgMetadataScore: Int?
    let avgLicenseScore: Int?
    let lastEvaluatedAt: String?

    var id: String { repositoryId }
}

/// A single quality check summary inside an artifact health report.
struct CheckSummary: Codable, Identifiable, Sendable, Equatable {
    let checkType: String
    let status: String
    let issuesCount: Int
    let passed: Bool?
    let score: Int?
    let completedAt: String?

    // Checks have no server id; the check type is unique within a report.
    var id: String { checkType }
}

/// Per-artifact health report (GET /api/v1/quality/health/artifacts/{artifact_id}).
struct ArtifactHealth: Sendable, Equatable {
    let artifactId: String
    let healthScore: Int
    let healthGrade: String
    let totalIssues: Int
    let criticalIssues: Int
    let checksPassed: Int
    let checksTotal: Int
    let securityScore: Int?
    let qualityScore: Int?
    let metadataScore: Int?
    let licenseScore: Int?
    let lastCheckedAt: String?
    let checks: [CheckSummary]
}

/// The quality health dashboard (GET /api/v1/quality/health/dashboard).
struct HealthDashboard: Sendable, Equatable {
    let totalRepositories: Int
    let totalArtifactsEvaluated: Int
    let avgHealthScore: Int
    let reposGradeA: Int
    let reposGradeB: Int
    let reposGradeC: Int
    let reposGradeD: Int
    let reposGradeF: Int
    let repositories: [RepoHealth]
}

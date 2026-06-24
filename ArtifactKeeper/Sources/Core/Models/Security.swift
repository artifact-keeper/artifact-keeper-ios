import Foundation

struct DashboardSummary: Codable, Sendable {
    let reposWithScanning: Int
    let totalScans: Int
    let totalFindings: Int
    let criticalFindings: Int
    let highFindings: Int
    let reposGradeA: Int
    let reposGradeF: Int
    
    enum CodingKeys: String, CodingKey {
        case reposWithScanning = "repos_with_scanning"
        case totalScans = "total_scans"
        case totalFindings = "total_findings"
        case criticalFindings = "critical_findings"
        case highFindings = "high_findings"
        case reposGradeA = "repos_grade_a"
        case reposGradeF = "repos_grade_f"
    }
}

struct ScanResult: Codable, Identifiable, Sendable {
    let id: String
    let artifactId: String
    let scanType: String
    let status: String
    let findingsCount: Int
    let criticalCount: Int
    let highCount: Int
    let mediumCount: Int
    let lowCount: Int
    let startedAt: String?
    let completedAt: String?
    let errorMessage: String?
    let artifactName: String?
    let artifactVersion: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case artifactId = "artifact_id"
        case scanType = "scan_type"
        case findingsCount = "findings_count"
        case criticalCount = "critical_count"
        case highCount = "high_count"
        case mediumCount = "medium_count"
        case lowCount = "low_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case errorMessage = "error_message"
        case artifactName = "artifact_name"
        case artifactVersion = "artifact_version"
    }
}

struct ScanFinding: Codable, Identifiable, Sendable {
    let id: String
    let scanResultId: String
    let artifactId: String
    let severity: String
    let title: String
    let description: String?
    let cveId: String?
    let affectedComponent: String?
    let affectedVersion: String?
    let fixedVersion: String?
    let source: String?
    let sourceUrl: String?
    let isAcknowledged: Bool
    let acknowledgedBy: String?
    let acknowledgedReason: String?
    let acknowledgedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, severity, title, description, source
        case scanResultId = "scan_result_id"
        case artifactId = "artifact_id"
        case cveId = "cve_id"
        case affectedComponent = "affected_component"
        case affectedVersion = "affected_version"
        case fixedVersion = "fixed_version"
        case sourceUrl = "source_url"
        case isAcknowledged = "is_acknowledged"
        case acknowledgedBy = "acknowledged_by"
        case acknowledgedReason = "acknowledged_reason"
        case acknowledgedAt = "acknowledged_at"
        case createdAt = "created_at"
    }
}

struct ScanFindingListResponse: Codable, Sendable {
    let items: [ScanFinding]
}

struct ScanListResponse: Codable, Sendable {
    let items: [ScanResult]
    let total: Int
}

struct RepoSecurityScore: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let repositoryId: String
    let grade: String
    let score: Int
    let criticalCount: Int
    let highCount: Int
    let mediumCount: Int
    let lowCount: Int
    // 1.2.1 ScoreResponse adds these fields. Optional so existing decode sites and the
    // Hashable/Identifiable conformances stay backward compatible.
    var totalFindings: Int?
    var acknowledgedCount: Int?
    var lastScanAt: String?
    var calculatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, grade, score
        case repositoryId = "repository_id"
        case criticalCount = "critical_count"
        case highCount = "high_count"
        case mediumCount = "medium_count"
        case lowCount = "low_count"
        case totalFindings = "total_findings"
        case acknowledgedCount = "acknowledged_count"
        case lastScanAt = "last_scan_at"
        case calculatedAt = "calculated_at"
    }

    init(
        id: String,
        repositoryId: String,
        grade: String,
        score: Int,
        criticalCount: Int,
        highCount: Int,
        mediumCount: Int,
        lowCount: Int,
        totalFindings: Int? = nil,
        acknowledgedCount: Int? = nil,
        lastScanAt: String? = nil,
        calculatedAt: String? = nil
    ) {
        self.id = id
        self.repositoryId = repositoryId
        self.grade = grade
        self.score = score
        self.criticalCount = criticalCount
        self.highCount = highCount
        self.mediumCount = mediumCount
        self.lowCount = lowCount
        self.totalFindings = totalFindings
        self.acknowledgedCount = acknowledgedCount
        self.lastScanAt = lastScanAt
        self.calculatedAt = calculatedAt
    }
}

// MARK: - Security Dashboard (1.2.1 DashboardResponse)

struct SecurityDashboard: Sendable, Equatable {
    let reposWithScanning: Int
    let totalScans: Int
    let totalFindings: Int
    let criticalFindings: Int
    let highFindings: Int
    let policyViolationsBlocked: Int
    let reposGradeA: Int
    let reposGradeF: Int
}

// MARK: - Trigger Scan (1.2.1 TriggerScanResponse)

struct TriggerScanResult: Sendable, Equatable {
    let artifactsQueued: Int
    let message: String
}

// MARK: - Scan Configuration (1.2.1 ScanConfigResponse)

/// Per-repository scan configuration returned by `GET /api/v1/security/configs`.
struct ScanConfig: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let repositoryId: String
    let scanEnabled: Bool
    let scanOnUpload: Bool
    let scanOnProxy: Bool
    let blockOnPolicyViolation: Bool
    let severityThreshold: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case repositoryId = "repository_id"
        case scanEnabled = "scan_enabled"
        case scanOnUpload = "scan_on_upload"
        case scanOnProxy = "scan_on_proxy"
        case blockOnPolicyViolation = "block_on_policy_violation"
        case severityThreshold = "severity_threshold"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

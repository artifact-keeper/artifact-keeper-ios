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
    
    enum CodingKeys: String, CodingKey {
        case id, grade, score
        case repositoryId = "repository_id"
        case criticalCount = "critical_count"
        case highCount = "high_count"
        case mediumCount = "medium_count"
        case lowCount = "low_count"
    }
}

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
    }
}

struct ScanListResponse: Codable, Sendable {
    let items: [ScanResult]
    let total: Int
}

struct RepoSecurityScore: Codable, Identifiable, Sendable {
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

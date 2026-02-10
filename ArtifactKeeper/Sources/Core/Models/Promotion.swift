import Foundation

// MARK: - Policy Status

enum PolicyStatus: String, Codable, Sendable {
    case passing
    case failing
    case warning
    case pending

    var color: String {
        switch self {
        case .passing: return "green"
        case .failing: return "red"
        case .warning: return "yellow"
        case .pending: return "gray"
        }
    }
}

// MARK: - Policy Violation

struct PolicyViolation: Codable, Identifiable, Sendable {
    let id: String
    let policyId: String
    let policyName: String
    let severity: String
    let message: String
    let details: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case policyId = "policy_id"
        case policyName = "policy_name"
        case severity, message, details
        case createdAt = "created_at"
    }
}

// MARK: - CVE Summary

struct CveSummary: Codable, Sendable {
    let total: Int
    let critical: Int
    let high: Int
    let medium: Int
    let low: Int
    let unpatched: Int

    enum CodingKeys: String, CodingKey {
        case total, critical, high, medium, low, unpatched
    }
}

// MARK: - License Summary

struct LicenseSummary: Codable, Sendable {
    let total: Int
    let approved: Int
    let rejected: Int
    let unknown: Int
    let licenses: [String]?

    enum CodingKeys: String, CodingKey {
        case total, approved, rejected, unknown, licenses
    }
}

// MARK: - Staging Artifact

struct StagingArtifact: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let repositoryKey: String
    let name: String
    let path: String
    let version: String?
    let contentType: String?
    let sizeBytes: Int64
    let policyStatus: String
    let cveSummary: CveSummary?
    let licenseSummary: LicenseSummary?
    let violations: [PolicyViolation]?
    let createdAt: String
    let promotedAt: String?
    let promotedBy: String?
    let promotedToRepo: String?

    enum CodingKeys: String, CodingKey {
        case id, name, path, version
        case repositoryKey = "repository_key"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case policyStatus = "policy_status"
        case cveSummary = "cve_summary"
        case licenseSummary = "license_summary"
        case violations
        case createdAt = "created_at"
        case promotedAt = "promoted_at"
        case promotedBy = "promoted_by"
        case promotedToRepo = "promoted_to_repo"
    }

    // Hashable conformance (only id needed for uniqueness)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StagingArtifact, rhs: StagingArtifact) -> Bool {
        lhs.id == rhs.id
    }
}

struct StagingArtifactListResponse: Codable, Sendable {
    let items: [StagingArtifact]
    let pagination: Pagination?
}

// MARK: - Staging Repository

struct StagingRepository: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let key: String
    let name: String
    let format: String
    let targetRepoKey: String?
    let artifactCount: Int
    let pendingCount: Int
    let passingCount: Int
    let failingCount: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, key, name, format
        case targetRepoKey = "target_repo_key"
        case artifactCount = "artifact_count"
        case pendingCount = "pending_count"
        case passingCount = "passing_count"
        case failingCount = "failing_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Hashable conformance (only id needed for uniqueness)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StagingRepository, rhs: StagingRepository) -> Bool {
        lhs.id == rhs.id
    }
}

struct StagingRepositoryListResponse: Codable, Sendable {
    let items: [StagingRepository]
    let pagination: Pagination?
}

// MARK: - Promotion Request/Response

struct PromotionRequest: Encodable, Sendable {
    let targetRepoKey: String
    let force: Bool?
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case targetRepoKey = "target_repo_key"
        case force, comment
    }
}

struct PromotionResponse: Codable, Sendable {
    let success: Bool
    let artifactId: String
    let targetRepoKey: String
    let promotedPath: String?
    let message: String?
    let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case success
        case artifactId = "artifact_id"
        case targetRepoKey = "target_repo_key"
        case promotedPath = "promoted_path"
        case message, warnings
    }

    init(
        success: Bool,
        artifactId: String,
        targetRepoKey: String,
        promotedPath: String?,
        message: String?,
        warnings: [String]?
    ) {
        self.success = success
        self.artifactId = artifactId
        self.targetRepoKey = targetRepoKey
        self.promotedPath = promotedPath
        self.message = message
        self.warnings = warnings
    }
}

struct BulkPromotionRequest: Encodable, Sendable {
    let artifactIds: [String]
    let targetRepoKey: String
    let force: Bool?
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case artifactIds = "artifact_ids"
        case targetRepoKey = "target_repo_key"
        case force, comment
    }
}

struct BulkPromotionResult: Codable, Sendable {
    let artifactId: String
    let success: Bool
    let message: String?
    let promotedPath: String?

    enum CodingKeys: String, CodingKey {
        case artifactId = "artifact_id"
        case success, message
        case promotedPath = "promoted_path"
    }

    init(artifactId: String, success: Bool, message: String?, promotedPath: String?) {
        self.artifactId = artifactId
        self.success = success
        self.message = message
        self.promotedPath = promotedPath
    }
}

struct BulkPromotionResponse: Codable, Sendable {
    let totalRequested: Int
    let totalSucceeded: Int
    let totalFailed: Int
    let results: [BulkPromotionResult]

    enum CodingKeys: String, CodingKey {
        case totalRequested = "total_requested"
        case totalSucceeded = "total_succeeded"
        case totalFailed = "total_failed"
        case results
    }

    init(totalRequested: Int, totalSucceeded: Int, totalFailed: Int, results: [BulkPromotionResult]) {
        self.totalRequested = totalRequested
        self.totalSucceeded = totalSucceeded
        self.totalFailed = totalFailed
        self.results = results
    }
}

// MARK: - Promotion History

struct PromotionHistoryEntry: Codable, Identifiable, Sendable {
    let id: String
    let artifactId: String
    let artifactName: String
    let artifactVersion: String?
    let sourceRepoKey: String
    let targetRepoKey: String
    let promotedBy: String
    let promotedByUsername: String?
    let comment: String?
    let wasForced: Bool
    let promotedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case artifactId = "artifact_id"
        case artifactName = "artifact_name"
        case artifactVersion = "artifact_version"
        case sourceRepoKey = "source_repo_key"
        case targetRepoKey = "target_repo_key"
        case promotedBy = "promoted_by"
        case promotedByUsername = "promoted_by_username"
        case comment
        case wasForced = "was_forced"
        case promotedAt = "promoted_at"
    }

    init(
        id: String,
        artifactId: String,
        artifactName: String,
        artifactVersion: String?,
        sourceRepoKey: String,
        targetRepoKey: String,
        promotedBy: String,
        promotedByUsername: String?,
        comment: String?,
        wasForced: Bool,
        promotedAt: String
    ) {
        self.id = id
        self.artifactId = artifactId
        self.artifactName = artifactName
        self.artifactVersion = artifactVersion
        self.sourceRepoKey = sourceRepoKey
        self.targetRepoKey = targetRepoKey
        self.promotedBy = promotedBy
        self.promotedByUsername = promotedByUsername
        self.comment = comment
        self.wasForced = wasForced
        self.promotedAt = promotedAt
    }
}

struct PromotionHistoryResponse: Codable, Sendable {
    let items: [PromotionHistoryEntry]
    let pagination: Pagination?
}

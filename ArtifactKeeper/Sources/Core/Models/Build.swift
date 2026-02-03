import Foundation

struct BuildItem: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let number: Int
    let status: String
    let startedAt: String?
    let finishedAt: String?
    let durationMs: Int64?
    let agent: String?
    let createdAt: String
    let updatedAt: String
    let artifactCount: Int?
    let vcsUrl: String?
    let vcsRevision: String?
    let vcsBranch: String?
    let vcsMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, name, number, status, agent
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationMs = "duration_ms"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case artifactCount = "artifact_count"
        case vcsUrl = "vcs_url"
        case vcsRevision = "vcs_revision"
        case vcsBranch = "vcs_branch"
        case vcsMessage = "vcs_message"
    }
}

struct BuildListResponse: Codable, Sendable {
    let items: [BuildItem]
    let pagination: Pagination?
}

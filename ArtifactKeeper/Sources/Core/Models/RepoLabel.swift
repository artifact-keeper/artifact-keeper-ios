import Foundation

// MARK: - Repository Labels (1.2.1 /api/v1/repositories/{key}/labels)

/// A repository-scoped label (key/value). Mirrors ArtifactLabel but scoped to a
/// repository.
struct RepoLabel: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let repositoryId: String
    let key: String
    let value: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, key, value
        case repositoryId = "repository_id"
        case createdAt = "created_at"
    }
}

struct RepoLabelsListResponse: Codable, Sendable {
    let items: [RepoLabel]
    let total: Int
}

/// One key/value entry for a bulk set.
struct RepoLabelEntry: Codable, Sendable {
    let key: String
    let value: String?
}

/// Body for PUT /api/v1/repositories/{key}/labels (replace the full set).
struct SetRepoLabelsRequest: Codable, Sendable {
    let labels: [RepoLabelEntry]
}

/// Body for POST /api/v1/repositories/{key}/labels/{label_key}.
struct AddRepoLabelRequest: Codable, Sendable {
    let value: String?
}

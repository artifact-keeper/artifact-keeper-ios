import Foundation

// MARK: - Repository Tokens (1.2.1 /api/v1/repositories/{key}/tokens)

/// A repository-scoped access token (list/get). The secret value is only
/// returned once at creation; list/get expose just the prefix.
struct RepoToken: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let tokenPrefix: String
    let scopes: [String]
    let createdAt: String
    let createdBy: String?
    let expiresAt: String?
    let lastUsedAt: String?
    let isExpired: Bool
    let isRevoked: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, scopes
        case tokenPrefix = "token_prefix"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case isExpired = "is_expired"
        case isRevoked = "is_revoked"
    }
}

struct RepoTokenListResponse: Codable, Sendable {
    let items: [RepoToken]
}

/// Body for POST /api/v1/repositories/{key}/tokens.
struct CreateRepoTokenRequest: Encodable {
    let name: String
    let scopes: [String]
    let description: String?
    let expiresInDays: Int?

    enum CodingKeys: String, CodingKey {
        case name, scopes, description
        case expiresInDays = "expires_in_days"
    }
}

/// Response from creating a token. The `token` secret is shown only here.
struct CreateRepoTokenResponse: Codable, Sendable {
    let id: String
    let name: String
    let token: String
    let repositoryKey: String

    enum CodingKeys: String, CodingKey {
        case id, name, token
        case repositoryKey = "repository_key"
    }
}

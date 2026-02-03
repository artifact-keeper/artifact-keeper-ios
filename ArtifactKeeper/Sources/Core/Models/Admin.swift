import Foundation

struct AdminUser: Codable, Identifiable, Sendable {
    let id: String
    let username: String
    let email: String?
    let displayName: String?
    let authProvider: String?
    let isActive: Bool
    let isAdmin: Bool
    let mustChangePassword: Bool?
    let lastLoginAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case displayName = "display_name"
        case authProvider = "auth_provider"
        case isActive = "is_active"
        case isAdmin = "is_admin"
        case mustChangePassword = "must_change_password"
        case lastLoginAt = "last_login_at"
        case createdAt = "created_at"
    }
}

struct AdminUserListResponse: Codable, Sendable {
    let items: [AdminUser]
    let pagination: PaginationInfo?
}

struct CreateUserResponse: Codable, Sendable {
    let user: AdminUser
    let generatedPassword: String?

    enum CodingKeys: String, CodingKey {
        case user
        case generatedPassword = "generated_password"
    }
}

struct PaginationInfo: Codable, Sendable {
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}

struct AdminGroup: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let memberCount: Int
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AdminGroupListResponse: Codable, Sendable {
    let items: [AdminGroup]
    let pagination: PaginationInfo?
}

struct SSOProvider: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let providerType: String
    let enabled: Bool
    let clientId: String?
    let issuerUrl: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, enabled
        case providerType = "provider_type"
        case clientId = "client_id"
        case issuerUrl = "issuer_url"
        case createdAt = "created_at"
    }
}

struct SSOProviderListResponse: Codable, Sendable {
    let items: [SSOProvider]
    let pagination: PaginationInfo?
}

struct SecurityPolicy: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let repositoryId: String?
    let maxSeverity: String
    let blockUnscanned: Bool
    let blockOnFail: Bool
    let isEnabled: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case repositoryId = "repository_id"
        case maxSeverity = "max_severity"
        case blockUnscanned = "block_unscanned"
        case blockOnFail = "block_on_fail"
        case isEnabled = "is_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TriggerScanResponse: Codable, Sendable {
    let message: String
    let artifactsQueued: Int

    enum CodingKeys: String, CodingKey {
        case message
        case artifactsQueued = "artifacts_queued"
    }
}

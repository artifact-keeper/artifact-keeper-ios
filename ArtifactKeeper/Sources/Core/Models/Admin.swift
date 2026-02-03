import Foundation

struct AdminUser: Codable, Identifiable, Sendable {
    let id: String
    let username: String
    let email: String?
    let isAdmin: Bool
    let isActive: Bool
    let createdAt: String
    let lastLoginAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case isAdmin = "is_admin"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }
}

struct AdminUserListResponse: Codable, Sendable {
    let items: [AdminUser]
    let total: Int
}

struct AdminGroup: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let memberCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case memberCount = "member_count"
        case createdAt = "created_at"
    }
}

struct AdminGroupListResponse: Codable, Sendable {
    let items: [AdminGroup]
    let total: Int
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
    let total: Int
}

struct SecurityPolicy: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let policyType: String
    let enabled: Bool
    let rules: [String]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, enabled, rules
        case policyType = "policy_type"
        case createdAt = "created_at"
    }
}

struct SecurityPolicyListResponse: Codable, Sendable {
    let items: [SecurityPolicy]
    let total: Int
}

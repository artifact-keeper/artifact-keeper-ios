import Foundation

struct Repository: Codable, Identifiable, Sendable {
    let id: String
    let key: String
    let name: String
    let format: String
    let repoType: String
    let isPublic: Bool
    let description: String?
    let storageUsedBytes: Int64
    let quotaBytes: Int64?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, key, name, format, description
        case repoType = "repo_type"
        case isPublic = "is_public"
        case storageUsedBytes = "storage_used_bytes"
        case quotaBytes = "quota_bytes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        key: String,
        name: String,
        format: String,
        repoType: String,
        isPublic: Bool,
        description: String?,
        storageUsedBytes: Int64,
        quotaBytes: Int64?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.format = format
        self.repoType = repoType
        self.isPublic = isPublic
        self.description = description
        self.storageUsedBytes = storageUsedBytes
        self.quotaBytes = quotaBytes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct RepositoryListResponse: Codable, Sendable {
    let items: [Repository]
    let pagination: Pagination?
}

struct Pagination: Codable, Sendable {
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}

struct CreateRepositoryRequest: Codable, Sendable {
    let key: String
    let name: String
    let format: String
    let repoType: String
    let isPublic: Bool
    let description: String?
    let upstreamUrl: String?

    enum CodingKeys: String, CodingKey {
        case key, name, format, description
        case repoType = "repo_type"
        case isPublic = "is_public"
        case upstreamUrl = "upstream_url"
    }

    init(
        key: String,
        name: String,
        format: String,
        repoType: String,
        isPublic: Bool = false,
        description: String? = nil,
        upstreamUrl: String? = nil
    ) {
        self.key = key
        self.name = name
        self.format = format
        self.repoType = repoType
        self.isPublic = isPublic
        self.description = description
        self.upstreamUrl = upstreamUrl
    }
}

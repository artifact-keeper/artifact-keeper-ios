import Foundation

struct PackageItem: Codable, Identifiable, Sendable {
    let id: String
    let repositoryKey: String
    let name: String
    let version: String
    let format: String
    let description: String?
    let sizeBytes: Int64
    let downloadCount: Int64
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, version, format, description
        case repositoryKey = "repository_key"
        case sizeBytes = "size_bytes"
        case downloadCount = "download_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PackageVersion: Codable, Identifiable, Sendable {
    let version: String
    let sizeBytes: Int64
    let downloadCount: Int64
    let createdAt: String
    let checksumSha256: String

    var id: String { version }

    enum CodingKeys: String, CodingKey {
        case version
        case sizeBytes = "size_bytes"
        case downloadCount = "download_count"
        case createdAt = "created_at"
        case checksumSha256 = "checksum_sha256"
    }
}

struct PackageListResponse: Codable, Sendable {
    let items: [PackageItem]
    let pagination: Pagination?
}

struct PackageVersionsResponse: Codable, Sendable {
    let versions: [PackageVersion]
}

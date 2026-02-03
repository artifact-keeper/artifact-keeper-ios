import Foundation

struct Artifact: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let repositoryId: String
    let name: String
    let path: String
    let version: String?
    let contentType: String
    let sizeBytes: Int64
    let downloadCount: Int
    let checksumSha256: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, path, version
        case repositoryId = "repository_id"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case downloadCount = "download_count"
        case checksumSha256 = "checksum_sha256"
        case createdAt = "created_at"
    }
}

struct ArtifactListResponse: Codable, Sendable {
    let items: [Artifact]
    let pagination: Pagination?
}

import Foundation

// Models for the 1.2.1 repository tree browser (GET /api/v1/tree) and package
// version listing (GET /api/v1/packages/{id}/versions). Decoded directly from the
// REST responses, matching the raw-request house pattern.

struct TreeNode: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    /// "directory" or "file" (server-defined). Used to choose the row icon and
    /// whether the node is drillable.
    let type: String
    let hasChildren: Bool
    let childrenCount: Int?
    let sizeBytes: Int64?
    let repositoryKey: String?
    let createdAt: String?

    var isDirectory: Bool {
        // Treat anything that can have children as a directory, falling back to the
        // type string for explicit directory nodes.
        hasChildren || type.lowercased() == "directory" || type.lowercased() == "dir" || type.lowercased() == "folder"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, type
        case hasChildren = "has_children"
        case childrenCount = "children_count"
        case sizeBytes = "size_bytes"
        case repositoryKey = "repository_key"
        case createdAt = "created_at"
    }
}

struct TreeResponse: Codable, Sendable {
    let nodes: [TreeNode]
}

// Note: PackageVersion / PackageVersionsResponse already exist in Package.swift and
// are consumed by PackageDetailView, so they are not redefined here.

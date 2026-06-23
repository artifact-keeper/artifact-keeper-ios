import Foundation

// Models for the 1.2.1 Artifact Detail surface: GET /api/v1/artifacts/{id},
// /metadata, /stats, and the artifact-labels CRUD endpoints. These decode the
// REST responses directly (matching the existing raw-request pattern used across
// Features) so they are exercisable in tests via the mock URL protocol.

struct ArtifactDetail: Codable, Sendable, Identifiable {
    let id: String
    let repositoryKey: String
    let path: String
    let name: String
    let version: String?
    let contentType: String
    let sizeBytes: Int64
    let checksumSha256: String
    let downloadCount: Int
    let createdAt: String
    let cacheCachedAt: String?
    let cacheExpiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, path, version
        case repositoryKey = "repository_key"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case checksumSha256 = "checksum_sha256"
        case downloadCount = "download_count"
        case createdAt = "created_at"
        case cacheCachedAt = "cache_cached_at"
        case cacheExpiresAt = "cache_expires_at"
    }
}

struct ArtifactMetadata: Codable, Sendable {
    let artifactId: String
    let format: String
    // metadata and properties are free-form JSON objects in the spec. They are
    // surfaced to the UI as decoded key/value strings for display.
    let metadata: [String: JSONValue]?
    let properties: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case artifactId = "artifact_id"
        case format, metadata, properties
    }
}

struct ArtifactStats: Codable, Sendable {
    let artifactId: String
    let downloadCount: Int
    let firstDownloaded: String?
    let lastDownloaded: String?

    enum CodingKeys: String, CodingKey {
        case artifactId = "artifact_id"
        case downloadCount = "download_count"
        case firstDownloaded = "first_downloaded"
        case lastDownloaded = "last_downloaded"
    }
}

// MARK: - Labels

struct ArtifactLabel: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let artifactId: String
    let key: String
    let value: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, key, value
        case artifactId = "artifact_id"
        case createdAt = "created_at"
    }
}

struct ArtifactLabelsListResponse: Codable, Sendable {
    let items: [ArtifactLabel]
    let total: Int
}

struct ArtifactLabelEntry: Codable, Sendable {
    let key: String
    let value: String?
}

struct SetArtifactLabelsRequest: Codable, Sendable {
    let labels: [ArtifactLabelEntry]
}

struct AddArtifactLabelRequest: Codable, Sendable {
    let value: String?
}

// A minimal JSON value used to decode the free-form metadata/properties objects
// without losing data, so the detail screen can render arbitrary key/value pairs.
enum JSONValue: Codable, Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }

    /// A short display string for rendering scalar values in a list row.
    var displayString: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let a): return "[\(a.count) items]"
        case .object(let o): return "{\(o.count) fields}"
        }
    }
}

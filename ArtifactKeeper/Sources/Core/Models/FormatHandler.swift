import Foundation

// MARK: - Format Handlers (1.2.1 /api/v1/formats/*)

/// A registered format handler (GET /api/v1/formats, GET /api/v1/formats/{format_key}).
/// Handlers are either compiled-in (Core) or loaded from a WASM plugin (Wasm).
struct FormatHandler: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let formatKey: String
    let handlerType: String
    let displayName: String
    let description: String?
    let extensions: [String]
    let isEnabled: Bool
    let priority: Int
    let pluginId: String?
    let repositoryCount: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, description, extensions, priority
        case formatKey = "format_key"
        case handlerType = "handler_type"
        case displayName = "display_name"
        case isEnabled = "is_enabled"
        case pluginId = "plugin_id"
        case repositoryCount = "repository_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

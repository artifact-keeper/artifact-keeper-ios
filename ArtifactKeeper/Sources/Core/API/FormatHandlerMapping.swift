import Foundation
import ArtifactKeeperClient

// MARK: - SDK -> App Model Mapping (Format Handlers)
//
// Mirrors the other mapping files: the generated client returns snake_case
// fields, Int32 counts and Foundation.Date timestamps; the view layer uses the
// camelCase FormatHandler model with Int and ISO8601 date strings.

extension FormatHandler {
    init(from sdk: Components.Schemas.FormatHandlerResponse) {
        self.init(
            id: sdk.id,
            formatKey: sdk.format_key,
            handlerType: sdk.handler_type.rawValue,
            displayName: sdk.display_name,
            description: sdk.description,
            extensions: sdk.extensions,
            isEnabled: sdk.is_enabled,
            priority: Int(sdk.priority),
            pluginId: sdk.plugin_id,
            repositoryCount: sdk.repository_count.map(Int.init),
            createdAt: SecurityMapping.isoString(sdk.created_at),
            updatedAt: SecurityMapping.isoString(sdk.updated_at)
        )
    }
}

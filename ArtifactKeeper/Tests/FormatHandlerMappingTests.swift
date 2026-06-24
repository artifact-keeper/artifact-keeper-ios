import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

@Suite("Format Handler SDK Mapping Tests")
struct FormatHandlerMappingTests {

    private static let created = Date(timeIntervalSince1970: 1_700_000_000)
    private static let updated = Date(timeIntervalSince1970: 1_700_086_400)

    @Test func formatHandlerMapsAllFields() {
        let sdk = Components.Schemas.FormatHandlerResponse(
            capabilities: nil,
            created_at: Self.created,
            description: "Maven repository format",
            display_name: "Maven",
            extensions: ["jar", "pom"],
            format_key: "maven",
            handler_type: .Core,
            id: "fmt-1",
            is_enabled: true,
            plugin_id: nil,
            priority: 10,
            repository_count: 4,
            updated_at: Self.updated
        )

        let model = FormatHandler(from: sdk)

        #expect(model.id == "fmt-1")
        #expect(model.formatKey == "maven")
        #expect(model.handlerType == "Core")
        #expect(model.displayName == "Maven")
        #expect(model.description == "Maven repository format")
        #expect(model.extensions == ["jar", "pom"])
        #expect(model.isEnabled)
        #expect(model.priority == 10)
        #expect(model.pluginId == nil)
        #expect(model.repositoryCount == 4)
        #expect(model.createdAt == SecurityMapping.isoString(Self.created))
        #expect(model.updatedAt == SecurityMapping.isoString(Self.updated))
    }

    @Test func wasmHandlerTypeMaps() {
        let sdk = Components.Schemas.FormatHandlerResponse(
            capabilities: nil,
            created_at: Self.created,
            description: nil,
            display_name: "Unity",
            extensions: ["unitypackage"],
            format_key: "unity",
            handler_type: .Wasm,
            id: "fmt-2",
            is_enabled: false,
            plugin_id: "plg-9",
            priority: 5,
            repository_count: nil,
            updated_at: Self.updated
        )

        let model = FormatHandler(from: sdk)

        #expect(model.handlerType == "Wasm")
        #expect(!model.isEnabled)
        #expect(model.pluginId == "plg-9")
        #expect(model.repositoryCount == nil)
    }
}

import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - SavedServer Model Tests

@Suite("SavedServer Model Tests")
struct SavedServerModelTests {

    @Test func savedServerInitSetsProperties() {
        let server = SavedServer(name: "My Server", url: "https://registry.example.com")
        #expect(server.name == "My Server")
        #expect(server.url == "https://registry.example.com")
        #expect(!server.id.isEmpty)
    }

    @Test func savedServerGeneratesUniqueIds() {
        let a = SavedServer(name: "A", url: "https://a.example.com")
        let b = SavedServer(name: "B", url: "https://b.example.com")
        #expect(a.id != b.id)
    }

    @Test func savedServerCodableRoundTrip() throws {
        let original = SavedServer(name: "Test", url: "https://test.example.com")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SavedServer.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.url == original.url)
    }

    @Test func savedServerIsIdentifiable() {
        let server = SavedServer(name: "S", url: "https://s.test")
        // Identifiable requires an id property -- just verify it exists
        let id: String = server.id
        #expect(!id.isEmpty)
    }

    @Test func savedServerIsHashable() {
        let a = SavedServer(name: "A", url: "https://a.test")
        let b = SavedServer(name: "B", url: "https://b.test")
        var set: Set<SavedServer> = [a, b]
        #expect(set.count == 2)
        // Inserting same reference should not change count
        set.insert(a)
        #expect(set.count == 2)
    }

    @Test func savedServerIsSendable() {
        // This test verifies at compile time that SavedServer conforms to Sendable.
        // Under Swift 6 strict concurrency, this would fail to compile if not Sendable.
        let server = SavedServer(name: "S", url: "https://s.test")
        let _: any Sendable = server
        #expect(Bool(true))
    }

    @Test func savedServerMutableProperties() {
        var server = SavedServer(name: "Original", url: "https://original.test")
        server.name = "Updated"
        server.url = "https://updated.test"
        #expect(server.name == "Updated")
        #expect(server.url == "https://updated.test")
    }

    @Test func savedServerAddedAtIsSet() {
        let before = Date()
        let server = SavedServer(name: "S", url: "https://s.test")
        let after = Date()
        #expect(server.addedAt >= before)
        #expect(server.addedAt <= after)
    }
}

// MARK: - ServerManager Tests

@Suite("ServerManager Tests")
struct ServerManagerTests {

    /// Creates a fresh ServerManager for testing by clearing UserDefaults state
    /// that would persist between tests.
    private func cleanDefaults() {
        UserDefaults.standard.removeObject(forKey: "savedServers")
        UserDefaults.standard.removeObject(forKey: "activeServerId")
        UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
    }

    @Test @MainActor func initialStateHasNoServers() {
        cleanDefaults()
        let manager = ServerManager()
        #expect(manager.servers.isEmpty)
        #expect(manager.activeServerId == nil)
        #expect(manager.activeServer == nil)
    }

    @Test @MainActor func addServerAppendsAndAutoActivatesFirst() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "Test", url: "https://test.example.com")

        #expect(manager.servers.count == 1)
        #expect(manager.servers[0].name == "Test")
        #expect(manager.servers[0].url == "https://test.example.com")
        // First server should be auto-activated
        #expect(manager.activeServerId == manager.servers[0].id)
        #expect(manager.activeServer?.name == "Test")
    }

    @Test @MainActor func addServerStripsTrailingSlash() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "Slashed", url: "https://registry.example.com/")
        #expect(manager.servers[0].url == "https://registry.example.com")
    }

    @Test @MainActor func addMultipleServersDoesNotChangeActive() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "First", url: "https://first.test")
        let firstId = manager.activeServerId

        manager.addServer(name: "Second", url: "https://second.test")
        #expect(manager.servers.count == 2)
        // Active should still be the first one
        #expect(manager.activeServerId == firstId)
    }

    @Test @MainActor func removeServerClearsActiveWhenEmpty() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "Only", url: "https://only.test")
        let server = manager.servers[0]

        manager.removeServer(server)
        #expect(manager.servers.isEmpty)
        #expect(manager.activeServerId == nil)
    }

    @Test @MainActor func removeActiveServerFallsBackToFirst() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "A", url: "https://a.test")
        manager.addServer(name: "B", url: "https://b.test")

        let serverA = manager.servers[0]
        let serverB = manager.servers[1]

        // Activate B, then remove it
        manager.switchTo(serverB)
        #expect(manager.activeServerId == serverB.id)

        manager.removeServer(serverB)
        #expect(manager.servers.count == 1)
        // Should fall back to first remaining server
        #expect(manager.activeServerId == serverA.id)
    }

    @Test @MainActor func switchToUpdatesActiveServerId() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "A", url: "https://a.test")
        manager.addServer(name: "B", url: "https://b.test")

        let serverB = manager.servers[1]
        manager.switchTo(serverB)
        #expect(manager.activeServerId == serverB.id)
        #expect(manager.activeServer?.name == "B")
    }

    @Test @MainActor func serverStatusesStartEmpty() {
        cleanDefaults()
        let manager = ServerManager()
        #expect(manager.serverStatuses.isEmpty)
    }

    @Test @MainActor func activeServerReturnsNilWhenIdDoesNotMatch() {
        cleanDefaults()
        let manager = ServerManager()
        manager.addServer(name: "A", url: "https://a.test")
        // Force a mismatched ID
        manager.activeServerId = "nonexistent-id"
        #expect(manager.activeServer == nil)
    }
}

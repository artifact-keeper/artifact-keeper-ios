import Foundation
import SwiftUI

struct SavedServer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var url: String
    var addedAt: Date

    init(name: String, url: String) {
        self.id = UUID().uuidString
        self.name = name
        self.url = url
        self.addedAt = Date()
    }
}

@MainActor
class ServerManager: ObservableObject {
    static let shared = ServerManager()

    private static let serversKey = "savedServers"
    private static let activeServerKey = "activeServerId"

    @Published var servers: [SavedServer] = []
    @Published var activeServerId: String?

    var activeServer: SavedServer? {
        servers.first { $0.id == activeServerId }
    }

    init() {
        loadServers()
    }

    func addServer(name: String, url: String) {
        let cleaned = url.hasSuffix("/") ? String(url.dropLast()) : url
        let server = SavedServer(name: name, url: cleaned)
        servers.append(server)
        saveServers()

        // Auto-activate if it's the first server
        if servers.count == 1 {
            switchTo(server)
        }
    }

    func removeServer(_ server: SavedServer) {
        servers.removeAll { $0.id == server.id }
        if activeServerId == server.id {
            activeServerId = servers.first?.id
            if let active = activeServer {
                applyServer(active)
            } else {
                // No servers left — clear everything
                UserDefaults.standard.set("", forKey: APIClient.serverURLKey)
                Task { await APIClient.shared.updateBaseURL("") }
            }
            UserDefaults.standard.set(activeServerId, forKey: Self.activeServerKey)
        }
        saveServers()
    }

    func switchTo(_ server: SavedServer) {
        activeServerId = server.id
        UserDefaults.standard.set(server.id, forKey: Self.activeServerKey)
        applyServer(server)
    }

    private func applyServer(_ server: SavedServer) {
        UserDefaults.standard.set(server.url, forKey: APIClient.serverURLKey)
        Task { await APIClient.shared.updateBaseURL(server.url) }
    }

    // Migrate from old single-server storage
    func migrateIfNeeded() {
        if servers.isEmpty {
            let oldURL = UserDefaults.standard.string(forKey: APIClient.serverURLKey) ?? ""
            if !oldURL.isEmpty {
                let server = SavedServer(name: serverNameFromURL(oldURL), url: oldURL)
                servers.append(server)
                activeServerId = server.id
                saveServers()
                UserDefaults.standard.set(server.id, forKey: Self.activeServerKey)
            }
        }
    }

    private func serverNameFromURL(_ url: String) -> String {
        if let host = URL(string: url)?.host {
            if host == "localhost" || host == "127.0.0.1" {
                return "Local"
            }
            return host
        }
        return "Server"
    }

    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: Self.serversKey),
           let decoded = try? JSONDecoder().decode([SavedServer].self, from: data) {
            servers = decoded
        }
        activeServerId = UserDefaults.standard.string(forKey: Self.activeServerKey)
    }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: Self.serversKey)
        }
    }
}

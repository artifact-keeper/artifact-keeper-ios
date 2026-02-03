import SwiftUI

@main
struct ArtifactKeeperApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var serverManager = ServerManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(serverManager)
                .task {
                    serverManager.migrateIfNeeded()
                }
        }
    }
}

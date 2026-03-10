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
                    await configureTokenRefresh()
                    await authManager.restoreSession()
                }
        }
    }

    /// Wire up the APIClient's 401 retry callbacks so they flow through
    /// AuthManager for token refresh and forced logout.
    private func configureTokenRefresh() async {
        let authMgr = authManager
        await APIClient.shared.setTokenRefreshHandler { [weak authMgr] in
            guard let authMgr else { return false }
            return await authMgr.refreshToken()
        }
        await APIClient.shared.setAuthFailureHandler { [weak authMgr] in
            authMgr?.logout()
        }
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    @AppStorage(APIClient.serverURLKey) private var serverURL: String = ""

    var body: some View {
        Group {
            if serverURL.isEmpty {
                WelcomeView {
                    // URL was saved by WelcomeView, @AppStorage triggers refresh
                }
            } else if authManager.mustChangePassword {
                ChangePasswordView()
            } else {
                MainTabView()
                    .id(serverManager.activeServerId)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

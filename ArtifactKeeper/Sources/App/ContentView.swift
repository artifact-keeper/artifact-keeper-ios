import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage(APIClient.serverURLKey) private var serverURL: String = ""

    var body: some View {
        if serverURL.isEmpty {
            WelcomeView {
                // URL was saved by WelcomeView, @AppStorage triggers refresh
            }
        } else {
            MainTabView()
        }
    }
}

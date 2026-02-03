import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

            RepositoriesView()
                .tabItem {
                    Label("Repos", systemImage: "folder")
                }

            PackagesView()
                .tabItem {
                    Label("Packages", systemImage: "shippingbox")
                }

            BuildsView()
                .tabItem {
                    Label("Builds", systemImage: "hammer")
                }

            if authManager.isAuthenticated {
                SecurityView()
                    .tabItem {
                        Label("Security", systemImage: "shield.checkered")
                    }
            }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

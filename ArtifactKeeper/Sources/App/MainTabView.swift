import SwiftUI

struct MainTabView: View {
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

            SecurityView()
                .tabItem {
                    Label("Security", systemImage: "shield.checkered")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
    }
}

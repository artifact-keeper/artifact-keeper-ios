import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager

    private var isLoggedIn: Bool { authManager.isAuthenticated }
    private var isAdmin: Bool { authManager.currentUser?.isAdmin == true }

    var body: some View {
        TabView {
            ArtifactsSectionView()
                .tabItem {
                    Label("Artifacts", systemImage: "shippingbox")
                }

            if isLoggedIn {
                IntegrationSectionView()
                    .tabItem {
                        Label("Integration", systemImage: "link")
                    }

                SecuritySectionView()
                    .tabItem {
                        Label("Security", systemImage: "shield.checkered")
                    }

                OperationsSectionView()
                    .tabItem {
                        Label("Operations", systemImage: "chart.bar")
                    }
            }

            if isAdmin {
                AdminSectionView()
                    .tabItem {
                        Label("Admin", systemImage: "gearshape.2")
                    }
            }
        }
    }
}

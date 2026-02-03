import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        TabView {
            ArtifactsSectionView()
                .tabItem {
                    Label("Artifacts", systemImage: "shippingbox")
                }

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

            AdminSectionView()
                .tabItem {
                    Label("Admin", systemImage: "gearshape.2")
                }
        }
    }
}

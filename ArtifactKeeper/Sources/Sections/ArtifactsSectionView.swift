import SwiftUI

struct ArtifactsSectionView: View {
    @State private var selectedTab = "repositories"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Repos").tag("repositories")
                    Text("Packages").tag("packages")
                    Text("Builds").tag("builds")
                    Text("Search").tag("search")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch selectedTab {
                    case "repositories":
                        RepositoriesContentView()
                    case "packages":
                        PackagesContentView()
                    case "builds":
                        BuildsContentView()
                    case "search":
                        SearchContentView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Artifacts")
            .accountToolbar()
        }
    }
}

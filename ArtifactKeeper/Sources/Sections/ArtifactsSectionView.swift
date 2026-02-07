import SwiftUI

struct ArtifactsSectionView: View {
    @State private var selectedTab = "repositories"
    @State private var showingCreateRepoSheet = false
    @State private var createdVirtualRepoKey: String?
    @State private var refreshTrigger = UUID()

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
                        RepositoriesContentView(onCreateTapped: {
                            showingCreateRepoSheet = true
                        })
                        .id(refreshTrigger)
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
            .sheet(isPresented: $showingCreateRepoSheet) {
                CreateRepositorySheet(
                    onCreated: { repoKey, repoType in
                        refreshTrigger = UUID()
                        if repoType == "virtual" {
                            createdVirtualRepoKey = repoKey
                        }
                    }
                )
            }
            .sheet(item: $createdVirtualRepoKey) { repoKey in
                AddMembersAfterCreateSheet(repoKey: repoKey) {
                    createdVirtualRepoKey = nil
                }
            }
        }
    }
}

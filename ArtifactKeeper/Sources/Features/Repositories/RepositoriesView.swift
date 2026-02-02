import SwiftUI

struct RepositoriesView: View {
    @State private var repos: [Repository] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    private let apiClient = APIClient.shared
    
    var filteredRepos: [Repository] {
        if searchText.isEmpty {
            return repos
        }
        return repos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.key.localizedCaseInsensitiveContains(searchText) ||
            $0.format.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading repositories...")
                } else if filteredRepos.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredRepos) { repo in
                        NavigationLink(value: repo.key) {
                            RepoListItem(repo: repo)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Repositories")
            .searchable(text: $searchText, prompt: "Search repositories")
            .refreshable {
                await loadRepos()
            }
            .task {
                await loadRepos()
            }
            .navigationDestination(for: String.self) { key in
                RepositoryDetailView(repoKey: key)
            }
        }
    }
    
    private func loadRepos() async {
        isLoading = repos.isEmpty
        do {
            let response: RepositoryListResponse = try await apiClient.request("/api/v1/repositories?per_page=100")
            repos = response.items
        } catch {
            // silent for now
        }
        isLoading = false
    }
}

struct RepoListItem: View {
    let repo: Repository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repo.name)
                    .font(.body.weight(.medium))
                
                Spacer()
                
                Text(repo.format.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
            }
            
            HStack(spacing: 12) {
                Label("\(repo.artifactCount) artifacts", systemImage: "doc")
                Label(repo.repoType, systemImage: repo.repoType == "local" ? "internaldrive" : "globe")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RepositoryDetailView: View {
    let repoKey: String
    @State private var repo: Repository?
    @State private var artifacts: [Artifact] = []
    @State private var isLoading = true
    
    private let apiClient = APIClient.shared
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let repo = repo {
                List {
                    Section("Details") {
                        LabeledContent("Format", value: repo.format.uppercased())
                        LabeledContent("Type", value: repo.repoType)
                        LabeledContent("Storage", value: formatBytes(repo.storageUsedBytes))
                        LabeledContent("Public", value: repo.isPublic ? "Yes" : "No")
                        if let desc = repo.description {
                            LabeledContent("Description", value: desc)
                        }
                    }
                    
                    Section("Artifacts (\(artifacts.count))") {
                        ForEach(artifacts) { artifact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artifact.name)
                                    .font(.body.weight(.medium))
                                HStack(spacing: 8) {
                                    if let version = artifact.version {
                                        Text(version)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.1), in: Capsule())
                                    }
                                    Text(formatBytes(artifact.sizeBytes))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Label("\(artifact.downloadCount)", systemImage: "arrow.down.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle(repoKey)
        .task {
            do {
                async let repoResult: Repository = apiClient.request("/api/v1/repositories/\(repoKey)")
                async let artifactResult: ArtifactListResponse = apiClient.request("/api/v1/repositories/\(repoKey)/artifacts?per_page=100")
                
                let (r, a) = try await (repoResult, artifactResult)
                repo = r
                artifacts = a.items
            } catch {
                // handle error
            }
            isLoading = false
        }
    }
}

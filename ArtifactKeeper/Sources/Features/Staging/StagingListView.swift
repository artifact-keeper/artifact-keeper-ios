import SwiftUI

struct StagingListContentView: View {
    @State private var repos: [StagingRepository] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var filteredRepos: [StagingRepository] {
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
        Group {
            if isLoading {
                ProgressView("Loading staging repositories...")
            } else if let error = errorMessage, repos.isEmpty {
                ContentUnavailableView(
                    "Staging Unavailable",
                    systemImage: "tray.and.arrow.up",
                    description: Text(error)
                )
            } else if filteredRepos.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if repos.isEmpty {
                ContentUnavailableView(
                    "No Staging Repositories",
                    systemImage: "tray",
                    description: Text("No staging repositories configured. Create a staging repository to manage artifact promotion workflows.")
                )
            } else {
                List(filteredRepos) { repo in
                    NavigationLink(value: repo) {
                        StagingRepoRow(repo: repo)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search staging repos")
        .refreshable {
            await loadRepos()
        }
        .task {
            await loadRepos()
        }
        .navigationDestination(for: StagingRepository.self) { repo in
            StagingDetailView(repo: repo)
        }
    }

    private func loadRepos() async {
        isLoading = repos.isEmpty
        do {
            repos = try await apiClient.listStagingRepos()
            errorMessage = nil
        } catch {
            if repos.isEmpty {
                errorMessage = "Could not load staging repositories. You may need to be authenticated."
            }
        }
        isLoading = false
    }
}

struct StagingListView: View {
    @State private var repos: [StagingRepository] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var filteredRepos: [StagingRepository] {
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
                    ProgressView("Loading staging repositories...")
                } else if let error = errorMessage, repos.isEmpty {
                    ContentUnavailableView(
                        "Staging Unavailable",
                        systemImage: "tray.and.arrow.up",
                        description: Text(error)
                    )
                } else if filteredRepos.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if repos.isEmpty {
                    ContentUnavailableView(
                        "No Staging Repositories",
                        systemImage: "tray",
                        description: Text("No staging repositories configured. Create a staging repository to manage artifact promotion workflows.")
                    )
                } else {
                    List(filteredRepos) { repo in
                        NavigationLink(value: repo) {
                            StagingRepoRow(repo: repo)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Staging")
            .accountToolbar()
            .searchable(text: $searchText, prompt: "Search staging repos")
            .refreshable {
                await loadRepos()
            }
            .task {
                await loadRepos()
            }
            .navigationDestination(for: StagingRepository.self) { repo in
                StagingDetailView(repo: repo)
            }
        }
    }

    private func loadRepos() async {
        isLoading = repos.isEmpty
        do {
            repos = try await apiClient.listStagingRepos()
            errorMessage = nil
        } catch {
            if repos.isEmpty {
                errorMessage = "Could not load staging repositories. You may need to be authenticated."
            }
        }
        isLoading = false
    }
}

// MARK: - Staging Repo Row

struct StagingRepoRow: View {
    let repo: StagingRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            // Policy status summary
            HStack(spacing: 8) {
                if repo.passingCount > 0 {
                    PolicyStatusBadge(count: repo.passingCount, status: .passing)
                }
                if repo.failingCount > 0 {
                    PolicyStatusBadge(count: repo.failingCount, status: .failing)
                }
                if repo.pendingCount > 0 {
                    PolicyStatusBadge(count: repo.pendingCount, status: .pending)
                }

                Spacer()

                Label("\(repo.artifactCount)", systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let targetKey = repo.targetRepoKey {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption2)
                    Text(targetKey)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Policy Status Badge

struct PolicyStatusBadge: View {
    let count: Int
    let status: PolicyStatus

    private var color: Color {
        switch status {
        case .passing: return .green
        case .failing: return .red
        case .warning: return .yellow
        case .pending: return .gray
        }
    }

    private var icon: String {
        switch status {
        case .passing: return "checkmark.circle"
        case .failing: return "xmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .pending: return "clock"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

import SwiftUI

struct SearchContentView: View {
    @State private var searchText = ""
    @State private var repoResults: [Repository] = []
    @State private var artifactResults: [Artifact] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            // Inline search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search repositories & artifacts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        repoResults = []
                        artifactResults = []
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Results area
            if searchText.isEmpty && repoResults.isEmpty && artifactResults.isEmpty {
                ContentUnavailableView(
                    "Search",
                    systemImage: "magnifyingglass",
                    description: Text("Search across repositories and artifacts by name, key, or format")
                )
                .frame(maxHeight: .infinity)
            } else if isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if repoResults.isEmpty && artifactResults.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    if !repoResults.isEmpty {
                        Section("Repositories") {
                            ForEach(repoResults) { repo in
                                NavigationLink {
                                    RepositoryDetailView(repoKey: repo.key)
                                } label: {
                                    RepoSearchResultRow(repo: repo)
                                }
                            }
                        }
                    }
                    if !artifactResults.isEmpty {
                        Section("Artifacts") {
                            ForEach(artifactResults) { artifact in
                                ArtifactSearchResultRow(artifact: artifact)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()

            guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                repoResults = []
                artifactResults = []
                isSearching = false
                errorMessage = nil
                return
            }

            searchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await performSearch(query: newValue)
            }
        }
        .overlay(alignment: .bottom) {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.85), in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        errorMessage = nil

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        // Search repositories and artifacts in parallel
        async let repoSearch: RepositoryListResponse? = {
            do {
                return try await apiClient.request("/api/v1/repositories?search=\(encoded)&per_page=20")
            } catch {
                return nil
            }
        }()

        async let artifactSearch: ArtifactListResponse? = {
            do {
                return try await apiClient.request("/api/v1/packages?search=\(encoded)&per_page=20")
            } catch {
                return nil
            }
        }()

        let (repos, artifacts) = await (repoSearch, artifactSearch)

        guard !Task.isCancelled else { return }

        repoResults = repos?.items ?? []
        artifactResults = artifacts?.items ?? []

        if repoResults.isEmpty && artifactResults.isEmpty {
            // Both failed or empty — no error shown, just empty state
        }

        isSearching = false
    }
}

struct SearchView: View {
    @State private var searchText = ""
    @State private var repoResults: [Repository] = []
    @State private var artifactResults: [Artifact] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty && repoResults.isEmpty && artifactResults.isEmpty {
                    ContentUnavailableView(
                        "Search",
                        systemImage: "magnifyingglass",
                        description: Text("Search across repositories and artifacts by name, key, or format")
                    )
                } else if isSearching {
                    ProgressView("Searching...")
                } else if repoResults.isEmpty && artifactResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        if !repoResults.isEmpty {
                            Section("Repositories") {
                                ForEach(repoResults) { repo in
                                    NavigationLink {
                                        RepositoryDetailView(repoKey: repo.key)
                                    } label: {
                                        RepoSearchResultRow(repo: repo)
                                    }
                                }
                            }
                        }
                        if !artifactResults.isEmpty {
                            Section("Artifacts") {
                                ForEach(artifactResults) { artifact in
                                    ArtifactSearchResultRow(artifact: artifact)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .accountToolbar()
            .searchable(text: $searchText, prompt: "Search repositories & artifacts...")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()

                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    repoResults = []
                    artifactResults = []
                    isSearching = false
                    errorMessage = nil
                    return
                }

                searchTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await performSearch(query: newValue)
                }
            }
            .overlay(alignment: .bottom) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.85), in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        errorMessage = nil

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        async let repoSearch: RepositoryListResponse? = {
            do {
                return try await apiClient.request("/api/v1/repositories?search=\(encoded)&per_page=20")
            } catch {
                return nil
            }
        }()

        async let artifactSearch: ArtifactListResponse? = {
            do {
                return try await apiClient.request("/api/v1/packages?search=\(encoded)&per_page=20")
            } catch {
                return nil
            }
        }()

        let (repos, artifacts) = await (repoSearch, artifactSearch)

        guard !Task.isCancelled else { return }

        repoResults = repos?.items ?? []
        artifactResults = artifacts?.items ?? []

        isSearching = false
    }
}

// MARK: - Repository Search Result Row

struct RepoSearchResultRow: View {
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
                Label(repo.key, systemImage: "folder")

                Label(repo.repoType, systemImage: "archivebox")

                Spacer()

                Text(formatBytes(repo.storageUsedBytes))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Artifact Search Result Row

struct ArtifactSearchResultRow: View {
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(artifact.name)
                    .font(.body.weight(.medium))

                Spacer()

                if let contentType = artifact.contentType, !contentType.isEmpty {
                    Text(contentType)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.1), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                if let repoKey = artifact.repositoryKey {
                    Label(repoKey, systemImage: "folder")
                }

                if let version = artifact.version {
                    Label(version, systemImage: "tag")
                }

                Spacer()

                Text(formatBytes(artifact.sizeBytes))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

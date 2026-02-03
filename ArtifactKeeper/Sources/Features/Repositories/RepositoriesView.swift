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
    @State private var selectedArtifact: Artifact?

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
                            ArtifactRow(artifact: artifact, repoKey: repoKey)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedArtifact = artifact
                                }
                                .contextMenu {
                                    Button {
                                        openDownloadURL(artifact: artifact)
                                    } label: {
                                        Label("Download in Browser", systemImage: "safari")
                                    }

                                    Button {
                                        selectedArtifact = artifact
                                    } label: {
                                        Label("View Details", systemImage: "info.circle")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(repoKey)
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .sheet(item: $selectedArtifact) { artifact in
            ArtifactDetailSheet(artifact: artifact, repoKey: repoKey)
        }
    }

    private func loadData() async {
        isLoading = artifacts.isEmpty && repo == nil
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

    private func openDownloadURL(artifact: Artifact) {
        Task {
            if let url = await apiClient.buildDownloadURL(repoKey: repoKey, artifactPath: artifact.path) {
                #if os(iOS)
                await UIApplication.shared.open(url)
                #elseif os(macOS)
                await MainActor.run { _ = NSWorkspace.shared.open(url) }
                #endif
            }
        }
    }
}

// MARK: - Artifact Row

struct ArtifactRow: View {
    let artifact: Artifact
    let repoKey: String

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var body: some View {
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

// MARK: - Artifact Detail Sheet

struct ArtifactDetailSheet: View {
    let artifact: Artifact
    let repoKey: String
    @Environment(\.dismiss) private var dismiss

    private let apiClient = APIClient.shared

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Artifact Info") {
                    LabeledContent("Name", value: artifact.name)
                    LabeledContent("Path", value: artifact.path)
                    if let version = artifact.version {
                        LabeledContent("Version", value: version)
                    }
                    LabeledContent("Content Type", value: artifact.contentType)
                    LabeledContent("Size", value: formatBytes(artifact.sizeBytes))
                    LabeledContent("Downloads", value: "\(artifact.downloadCount)")
                }

                Section("Checksums") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SHA-256")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(artifact.checksumSha256)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button {
                        openDownloadURL()
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text("Download in Browser")
                        }
                    }
                }
            }
            .navigationTitle("Artifact Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func openDownloadURL() {
        Task {
            if let url = await apiClient.buildDownloadURL(repoKey: repoKey, artifactPath: artifact.path) {
                #if os(iOS)
                await UIApplication.shared.open(url)
                #elseif os(macOS)
                await MainActor.run { _ = NSWorkspace.shared.open(url) }
                #endif
            }
        }
    }
}

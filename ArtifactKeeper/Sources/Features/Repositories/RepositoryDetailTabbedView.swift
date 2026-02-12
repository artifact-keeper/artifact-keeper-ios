import SwiftUI

struct RepositoryDetailTabbedView: View {
    let repoKey: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var repo: Repository?
    @State private var artifacts: [Artifact] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = "artifacts"
    @State private var selectedArtifact: Artifact?
    @State private var securityArtifact: Artifact?
    @State private var searchText = ""
    @State private var showingEditSheet = false

    private let apiClient = APIClient.shared

    private var availableTabs: [(id: String, title: String)] {
        var tabs: [(id: String, title: String)] = [("artifacts", "Artifacts")]
        if authManager.isAuthenticated {
            tabs.append(("upload", "Upload"))
        }
        if repo?.repoType == "virtual" {
            tabs.append(("members", "Members"))
        }
        if authManager.currentUser?.isAdmin == true {
            tabs.append(("security", "Security"))
        }
        return tabs
    }

    private var filteredArtifacts: [Artifact] {
        if searchText.isEmpty { return artifacts }
        return artifacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && repo == nil {
                ProgressView("Loading\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, repo == nil {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if let repo {
                repoHeader(repo)
                tabBar
                Divider()
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadData()
        }
        .sheet(item: $selectedArtifact) { artifact in
            ArtifactDetailSheet(artifact: artifact, repoKey: repoKey)
        }
        .sheet(item: $securityArtifact) { artifact in
            NavigationStack {
                SbomView(artifactId: artifact.id, artifactName: artifact.name)
                    .navigationTitle(artifact.name)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { securityArtifact = nil }
                        }
                    }
            }
        }
        .toolbar {
            if authManager.isAuthenticated, repo != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let repo {
                EditRepositorySheet(repository: repo) { newKey in
                    if newKey != repoKey {
                        dismiss()
                    } else {
                        Task { await loadData() }
                    }
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func repoHeader(_ repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(repo.name)
                .font(.title2.weight(.semibold))

            HStack(spacing: 8) {
                Text(repo.format.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)

                Text(repo.repoType)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(repoTypeColor(repo.repoType).opacity(0.1), in: Capsule())
                    .foregroundStyle(repoTypeColor(repo.repoType))

                if !repo.isPublic {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(formatBytes(repo.storageUsedBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let desc = repo.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(availableTabs, id: \.id) { tab in
                    Button {
                        selectedTab = tab.id
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedTab == tab.id ? .semibold : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab.id ? Color.accentColor.opacity(0.1) : Color.clear)
                            .foregroundStyle(selectedTab == tab.id ? .primary : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case "artifacts":
            artifactsTab
        case "upload":
            RepoUploadView(repoKey: repoKey) {
                Task { await loadArtifacts() }
            }
        case "members":
            VirtualMembersView(repoKey: repoKey)
        case "security":
            RepoSecurityConfigView(repoKey: repoKey)
        default:
            EmptyView()
        }
    }

    // MARK: - Artifacts Tab

    private var artifactsTab: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search artifacts\u{2026}", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                Text("\(artifacts.count) artifacts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if filteredArtifacts.isEmpty && !artifacts.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
            } else if artifacts.isEmpty {
                ContentUnavailableView(
                    "No Artifacts",
                    systemImage: "archivebox",
                    description: Text("This repository has no artifacts yet")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(filteredArtifacts) { artifact in
                    ArtifactRow(
                        artifact: artifact,
                        repoKey: repoKey,
                        onSecurityTap: { securityArtifact = artifact }
                    )
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
                                securityArtifact = artifact
                            } label: {
                                Label("SBOM & Security", systemImage: "shield.fill")
                            }
                            Button {
                                selectedArtifact = artifact
                            } label: {
                                Label("View Details", systemImage: "info.circle")
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = artifacts.isEmpty && repo == nil

        do {
            let r: Repository = try await apiClient.request("/api/v1/repositories/\(repoKey)")
            repo = r
        } catch {
            errorMessage = error.localizedDescription
        }

        await loadArtifacts()
        isLoading = false
    }

    private func loadArtifacts() async {
        do {
            let response: ArtifactListResponse = try await apiClient.request(
                "/api/v1/repositories/\(repoKey)/artifacts?per_page=100"
            )
            artifacts = response.items
        } catch {
            // Artifacts may fail separately
        }
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

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func repoTypeColor(_ type: String) -> Color {
        switch type {
        case "local": return .green
        case "remote": return .blue
        case "virtual": return .purple
        default: return .secondary
        }
    }
}

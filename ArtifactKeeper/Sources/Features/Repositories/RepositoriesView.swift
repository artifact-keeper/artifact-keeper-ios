import SwiftUI

struct RepositoriesContentView: View {
    var onCreateTapped: (() -> Void)?

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
        VStack(spacing: 0) {
            Group {
                if isLoading {
                    ProgressView("Loading repositories...")
                        .frame(maxHeight: .infinity)
                } else if filteredRepos.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxHeight: .infinity)
                } else {
                    List(filteredRepos) { repo in
                        NavigationLink(value: repo.key) {
                            RepoListItem(repo: repo)
                        }
                    }
                    .listStyle(.plain)
                }
            }

            if let onCreateTapped {
                Divider()
                VStack(spacing: 8) {
                    Button {
                        onCreateTapped()
                    } label: {
                        Label("Create Repository", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
                .padding(.vertical, 16)
            }
        }
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

    func refresh() async {
        await loadRepos()
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

struct RepositoriesView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var repos: [Repository] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingCreateSheet = false
    @State private var createdVirtualRepoKey: String?

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
            .accountToolbar()
            .toolbar {
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
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
            .sheet(isPresented: $showingCreateSheet) {
                CreateRepositorySheet(
                    onCreated: { repoKey, repoType in
                        Task {
                            await loadRepos()
                        }
                        // Only show member selection for virtual repos
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

// Make String conform to Identifiable for sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct RepoListItem: View {
    let repo: Repository

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func repoTypeIcon(_ type: String) -> String {
        switch type {
        case "local": return "internaldrive"
        case "remote": return "globe"
        case "virtual": return "folder.badge.gearshape"
        default: return "folder"
        }
    }

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
                Label(repo.repoType, systemImage: repoTypeIcon(repo.repoType))
                Label(formatBytes(repo.storageUsedBytes), systemImage: "externaldrive")
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
    @State private var members: [VirtualMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedArtifact: Artifact?
    @State private var securityArtifact: Artifact?

    private let apiClient = APIClient.shared

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let error = errorMessage, repo == nil {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
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

                    if repo.repoType == "virtual" {
                        Section {
                            NavigationLink {
                                VirtualMembersView(repoKey: repoKey)
                            } label: {
                                HStack {
                                    Label("Members", systemImage: "folder.badge.gearshape")
                                    Spacer()
                                    Text("\(members.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text("Virtual Repository")
                        } footer: {
                            Text("Manage local and remote repositories aggregated by this virtual repository")
                        }
                    }

                    Section("Artifacts (\(artifacts.count))") {
                        ForEach(artifacts) { artifact in
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
    }

    private func loadData() async {
        isLoading = artifacts.isEmpty && repo == nil

        do {
            let r: Repository = try await apiClient.request("/api/v1/repositories/\(repoKey)")
            repo = r

            // Load members for virtual repos
            if r.repoType == "virtual" {
                members = try await apiClient.listVirtualMembers(repoKey: repoKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let a: ArtifactListResponse = try await apiClient.request("/api/v1/repositories/\(repoKey)/artifacts?per_page=100")
            artifacts = a.items
        } catch {
            // Artifacts may fail separately — that's OK
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
    var onSecurityTap: (() -> Void)?

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
                if let onSecurityTap {
                    Button {
                        onSecurityTap()
                    } label: {
                        Image(systemName: "shield.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("SBOM & Security")
                }
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
                    LabeledContent("Content Type", value: artifact.contentType ?? "unknown")
                    LabeledContent("Size", value: formatBytes(artifact.sizeBytes))
                    LabeledContent("Downloads", value: "\(artifact.downloadCount)")
                }

                if let checksum = artifact.checksumSha256, !checksum.isEmpty {
                    Section("Checksums") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SHA-256")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(checksum)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
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

// MARK: - Create Repository Sheet

struct CreateRepositorySheet: View {
    let onCreated: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var key = ""
    @State private var name = ""
    @State private var repoType = "local"
    @State private var format = "generic"
    @State private var isPublic = false
    @State private var description = ""
    @State private var upstreamUrl = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    private let repoTypes = ["local", "remote", "virtual"]
    private let formats = ["generic", "docker", "maven", "npm", "pypi", "cargo", "nuget", "go", "helm", "rpm", "debian"]

    private var isValid: Bool {
        !key.isEmpty && !name.isEmpty &&
        (repoType != "remote" || !upstreamUrl.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key", text: $key)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    TextField("Name", text: $name)
                } header: {
                    Text("Basic Info")
                } footer: {
                    Text("Key must be unique and cannot be changed later")
                }

                Section("Type & Format") {
                    Picker("Type", selection: $repoType) {
                        ForEach(repoTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }

                    Picker("Format", selection: $format) {
                        ForEach(formats, id: \.self) { fmt in
                            Text(fmt.uppercased()).tag(fmt)
                        }
                    }
                }

                if repoType == "remote" {
                    Section {
                        TextField("Upstream URL", text: $upstreamUrl)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .autocorrectionDisabled()
                    } header: {
                        Text("Remote Settings")
                    } footer: {
                        Text("Required. The upstream repository URL to proxy")
                    }
                }

                Section("Options") {
                    Toggle("Public", isOn: $isPublic)
                    TextField("Description (optional)", text: $description)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Repository")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createRepository()
                    }
                    .disabled(!isValid || isCreating)
                }
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    ProgressView()
                }
            }
        }
    }

    private func createRepository() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                let request = CreateRepositoryRequest(
                    key: key,
                    name: name,
                    format: format,
                    repoType: repoType,
                    isPublic: isPublic,
                    description: description.isEmpty ? nil : description,
                    upstreamUrl: repoType == "remote" ? upstreamUrl : nil
                )

                _ = try await apiClient.createRepository(request: request)

                dismiss()

                // If virtual, trigger member selection flow
                if repoType == "virtual" {
                    onCreated(key, repoType)
                } else {
                    onCreated(key, repoType)
                }
            } catch {
                errorMessage = error.localizedDescription
            }

            isCreating = false
        }
    }
}

// MARK: - Add Members After Create Sheet (for virtual repos)

struct AddMembersAfterCreateSheet: View {
    let repoKey: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var eligibleRepos: [Repository] = []
    @State private var selectedMembers: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false

    private let apiClient = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading repositories...")
                } else if eligibleRepos.isEmpty {
                    ContentUnavailableView(
                        "No Eligible Repositories",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Create local or remote repositories first, then add them as members")
                    )
                } else {
                    List(eligibleRepos) { repo in
                        Button {
                            toggleSelection(repo.key)
                        } label: {
                            HStack {
                                EligibleRepoRow(repo: repo)
                                Spacer()
                                if selectedMembers.contains(repo.key) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Members")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedMembers.count)") {
                        addSelectedMembers()
                    }
                    .disabled(selectedMembers.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
        }
        .task {
            await loadEligibleRepos()
        }
    }

    private func toggleSelection(_ key: String) {
        if selectedMembers.contains(key) {
            selectedMembers.remove(key)
        } else {
            selectedMembers.insert(key)
        }
    }

    private func loadEligibleRepos() async {
        isLoading = true

        do {
            let allRepos = try await apiClient.listRepositories()
            eligibleRepos = allRepos.filter { repo in
                (repo.repoType == "local" || repo.repoType == "remote") &&
                repo.key != repoKey
            }
        } catch {
            eligibleRepos = []
        }

        isLoading = false
    }

    private func addSelectedMembers() {
        isSaving = true

        Task {
            var priority = 1
            for memberKey in selectedMembers.sorted() {
                do {
                    _ = try await apiClient.addVirtualMember(
                        repoKey: repoKey,
                        memberKey: memberKey,
                        priority: priority
                    )
                    priority += 1
                } catch {
                    // Continue with others even if one fails
                }
            }

            dismiss()
            onDismiss()
        }
    }
}

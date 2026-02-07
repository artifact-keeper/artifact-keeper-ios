import SwiftUI

struct VirtualMembersView: View {
    let repoKey: String

    @State private var members: [VirtualMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var eligibleRepos: [Repository] = []
    @State private var isLoadingEligible = false

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading members...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if members.isEmpty {
                ContentUnavailableView(
                    "No Members",
                    systemImage: "folder.badge.plus",
                    description: Text("Add local or remote repositories as members")
                )
            } else {
                List {
                    ForEach(members.sorted(by: { $0.priority < $1.priority })) { member in
                        MemberRow(member: member)
                    }
                    .onDelete(perform: deleteMember)
                    .onMove(perform: moveMember)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Members")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await loadMembers()
        }
        .task {
            await loadMembers()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMemberSheet(
                repoKey: repoKey,
                eligibleRepos: eligibleRepos,
                isLoading: isLoadingEligible,
                onAdd: { memberKey in
                    await addMember(memberKey: memberKey)
                },
                onAppear: {
                    Task {
                        await loadEligibleRepos()
                    }
                }
            )
        }
    }

    private func loadMembers() async {
        isLoading = members.isEmpty
        errorMessage = nil

        do {
            members = try await apiClient.listVirtualMembers(repoKey: repoKey)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadEligibleRepos() async {
        isLoadingEligible = true

        do {
            let allRepos = try await apiClient.listRepositories()
            // Filter to only local and remote repos that aren't already members
            let memberKeys = Set(members.map { $0.memberRepoKey })
            eligibleRepos = allRepos.filter { repo in
                (repo.repoType == "local" || repo.repoType == "remote") &&
                !memberKeys.contains(repo.key) &&
                repo.key != repoKey
            }
        } catch {
            eligibleRepos = []
        }

        isLoadingEligible = false
    }

    private func addMember(memberKey: String) async {
        do {
            let nextPriority = (members.map { $0.priority }.max() ?? 0) + 1
            _ = try await apiClient.addVirtualMember(
                repoKey: repoKey,
                memberKey: memberKey,
                priority: nextPriority
            )
            await loadMembers()
        } catch {
            // Handle error silently for now
        }
    }

    private func deleteMember(at offsets: IndexSet) {
        let sortedMembers = members.sorted(by: { $0.priority < $1.priority })
        Task {
            for index in offsets {
                let member = sortedMembers[index]
                do {
                    try await apiClient.removeVirtualMember(
                        repoKey: repoKey,
                        memberKey: member.memberRepoKey
                    )
                } catch {
                    // Handle error silently for now
                }
            }
            await loadMembers()
        }
    }

    private func moveMember(from source: IndexSet, to destination: Int) {
        var sortedMembers = members.sorted(by: { $0.priority < $1.priority })
        sortedMembers.move(fromOffsets: source, toOffset: destination)

        // Build reorder request with new priorities
        let reorderedMembers = sortedMembers.enumerated().map { index, member in
            MemberPriority(memberKey: member.memberRepoKey, priority: index + 1)
        }

        Task {
            do {
                try await apiClient.reorderVirtualMembers(
                    repoKey: repoKey,
                    members: reorderedMembers
                )
                await loadMembers()
            } catch {
                // Reload to reset on error
                await loadMembers()
            }
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: VirtualMember

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(member.memberRepoName)
                    .font(.body.weight(.medium))

                Spacer()

                Text("#\(member.priority)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.2), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(
                    member.memberRepoType,
                    systemImage: member.memberRepoType == "local" ? "internaldrive" : "globe"
                )
                Text(member.memberRepoKey)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    let repoKey: String
    let eligibleRepos: [Repository]
    let isLoading: Bool
    let onAdd: (String) async -> Void
    let onAppear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isAdding = false

    var filteredRepos: [Repository] {
        if searchText.isEmpty {
            return eligibleRepos
        }
        return eligibleRepos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.key.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading repositories...")
                } else if eligibleRepos.isEmpty {
                    ContentUnavailableView(
                        "No Eligible Repositories",
                        systemImage: "folder.badge.questionmark",
                        description: Text("No local or remote repositories available to add")
                    )
                } else if filteredRepos.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredRepos) { repo in
                        Button {
                            addRepo(repo)
                        } label: {
                            EligibleRepoRow(repo: repo)
                        }
                        .disabled(isAdding)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Member")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search repositories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            onAppear()
        }
    }

    private func addRepo(_ repo: Repository) {
        isAdding = true
        Task {
            await onAdd(repo.key)
            dismiss()
        }
    }
}

struct EligibleRepoRow: View {
    let repo: Repository

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repo.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(repo.format.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 12) {
                Label(
                    repo.repoType,
                    systemImage: repo.repoType == "local" ? "internaldrive" : "globe"
                )
                Text(repo.key)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        VirtualMembersView(repoKey: "my-virtual-repo")
    }
}

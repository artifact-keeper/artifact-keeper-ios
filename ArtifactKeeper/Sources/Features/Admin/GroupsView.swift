import SwiftUI

struct GroupsView: View {
    @State private var groups: [AdminGroup] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddGroup = false

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading groups...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Groups Unavailable",
                    systemImage: "person.3",
                    description: Text(error)
                )
            } else {
                List {
                    if groups.isEmpty {
                        ContentUnavailableView(
                            "No Groups",
                            systemImage: "person.3",
                            description: Text("No groups configured. Tap + to create one.")
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(groups) { group in
                            GroupRow(group: group)
                        }
                    }

                    Section {
                        Button {
                            showingAddGroup = true
                        } label: {
                            Label("Add Group", systemImage: "plus.circle")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadGroups() }
        .task { await loadGroups() }
        .sheet(isPresented: $showingAddGroup) {
            NavigationStack {
                AddGroupView { await loadGroups() }
                    .navigationTitle("Add Group")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    private func loadGroups() async {
        isLoading = groups.isEmpty
        do {
            let response: AdminGroupListResponse = try await apiClient.request("/api/v1/groups")
            groups = response.items
            errorMessage = nil
        } catch {
            if groups.isEmpty {
                errorMessage = "Could not load groups. You may need admin privileges."
            }
        }
        isLoading = false
    }
}

struct GroupRow: View {
    let group: AdminGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name)
                .font(.body.weight(.medium))
            HStack {
                if let desc = group.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Label("\(group.memberCount)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Group Sheet

private struct CreateGroupBody: Encodable {
    let name: String
    let description: String?
}

struct AddGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared
    var onSaved: () async -> Void

    var body: some View {
        Form {
            Section("Group Info") {
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
                TextField("Description (optional)", text: $description)
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await createGroup() } }
                    .disabled(isSaving || name.isEmpty)
            }
        }
    }

    private func createGroup() async {
        isSaving = true
        errorMessage = nil
        do {
            let body = CreateGroupBody(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description
            )
            let _: AdminGroup = try await apiClient.request(
                "/api/v1/groups",
                method: "POST",
                body: body
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

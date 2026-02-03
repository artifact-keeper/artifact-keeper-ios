import SwiftUI

struct GroupsView: View {
    @State private var groups: [AdminGroup] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
            } else if groups.isEmpty {
                ContentUnavailableView(
                    "No Groups",
                    systemImage: "person.3",
                    description: Text("No groups configured. Create groups from the web interface.")
                )
            } else {
                List(groups) { group in
                    GroupRow(group: group)
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadGroups() }
        .task { await loadGroups() }
    }

    private func loadGroups() async {
        isLoading = groups.isEmpty
        do {
            let response: AdminGroupListResponse = try await apiClient.request("/api/v1/admin/groups")
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

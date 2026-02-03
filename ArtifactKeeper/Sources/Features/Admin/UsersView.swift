import SwiftUI

struct UsersView: View {
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading users...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Users Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(error)
                )
            } else if users.isEmpty {
                ContentUnavailableView(
                    "No Users",
                    systemImage: "person.2",
                    description: Text("No users found.")
                )
            } else {
                List(users) { user in
                    UserRow(user: user)
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadUsers() }
        .task { await loadUsers() }
    }

    private func loadUsers() async {
        isLoading = users.isEmpty
        do {
            let response: AdminUserListResponse = try await apiClient.request("/api/v1/admin/users")
            users = response.items
            errorMessage = nil
        } catch {
            if users.isEmpty {
                errorMessage = "Could not load users. You may need admin privileges."
            }
        }
        isLoading = false
    }
}

struct UserRow: View {
    let user: AdminUser

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: user.isAdmin ? "person.badge.shield.checkmark" : "person.circle")
                .font(.title2)
                .foregroundStyle(user.isAdmin ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.username)
                        .font(.body.weight(.medium))
                    if user.isAdmin {
                        Text("Admin")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 8) {
                    if let email = user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(user.isActive ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(user.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

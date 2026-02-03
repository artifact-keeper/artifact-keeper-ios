import SwiftUI

struct UsersView: View {
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddUser = false

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
            } else {
                List {
                    if users.isEmpty {
                        ContentUnavailableView(
                            "No Users",
                            systemImage: "person.2",
                            description: Text("No users found. Tap + to create one.")
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(users) { user in
                            UserRow(user: user)
                        }
                    }

                    Section {
                        Button {
                            showingAddUser = true
                        } label: {
                            Label("Add User", systemImage: "plus.circle")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadUsers() }
        .task { await loadUsers() }
        .sheet(isPresented: $showingAddUser) {
            NavigationStack {
                AddUserView { await loadUsers() }
                    .navigationTitle("Add User")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    private func loadUsers() async {
        isLoading = users.isEmpty
        do {
            let response: AdminUserListResponse = try await apiClient.request("/api/v1/users")
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
                    if let name = user.displayName, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let email = user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let provider = user.authProvider, provider != "local" {
                        Text(provider.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.1), in: Capsule())
                            .foregroundStyle(.orange)
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

// MARK: - Add User Sheet

private struct CreateUserBody: Encodable {
    let username: String
    let email: String
    let password: String?
    let display_name: String?
    let is_admin: Bool?
}

struct AddUserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isAdmin = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var generatedPassword: String?

    private let apiClient = APIClient.shared
    var onSaved: () async -> Void

    var body: some View {
        Form {
            Section("Required") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                TextField("Email", text: $email)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
            }

            Section {
                SecureField("Password (leave blank to auto-generate)", text: $password)
                    .autocorrectionDisabled()
            } header: {
                Text("Password")
            } footer: {
                Text("If left blank, a secure password will be generated and shown after creation.")
            }

            Section("Optional") {
                TextField("Display Name", text: $displayName)
                Toggle("Administrator", isOn: $isAdmin)
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if let generated = generatedPassword {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("User created successfully", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Generated password:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(generated)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 6))
                        Text("Copy this password now. It won't be shown again.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if generatedPassword != nil {
                    Button("Done") { dismiss() }
                } else {
                    Button("Create") { Task { await createUser() } }
                        .disabled(isSaving || username.isEmpty || email.isEmpty)
                }
            }
        }
    }

    private func createUser() async {
        isSaving = true
        errorMessage = nil
        do {
            let body = CreateUserBody(
                username: username.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                password: password.isEmpty ? nil : password,
                display_name: displayName.isEmpty ? nil : displayName,
                is_admin: isAdmin ? true : nil
            )
            let response: CreateUserResponse = try await apiClient.request(
                "/api/v1/users",
                method: "POST",
                body: body
            )
            generatedPassword = response.generatedPassword
            await onSaved()
            if generatedPassword == nil {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to create user: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

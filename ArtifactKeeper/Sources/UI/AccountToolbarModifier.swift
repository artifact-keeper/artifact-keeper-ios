import SwiftUI

struct AccountToolbarModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    @State private var showingLoginSheet = false
    @State private var showingDashboard = false
    @State private var showingAddServer = false
    @State private var showingProfile = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                // Leading: Dashboard + Server switcher
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 8) {
                        Button {
                            showingDashboard = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }

                        if serverManager.servers.count > 1 {
                            Menu {
                                ForEach(serverManager.servers) { server in
                                    Button {
                                        serverManager.switchTo(server)
                                        authManager.logout()  // Auto-logout when switching servers
                                    } label: {
                                        if serverManager.serverStatuses[server.id] == true {
                                            Label(server.name, systemImage: "checkmark.circle.fill")
                                                .symbolRenderingMode(.multicolor)
                                        } else {
                                            Label(server.name, systemImage: "xmark.circle")
                                        }
                                    }
                                }
                                Divider()
                                Button {
                                    showingAddServer = true
                                } label: {
                                    Label("Add Server", systemImage: "plus")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "server.rack")
                                    if let active = serverManager.activeServer {
                                        Text(active.name)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        } else {
                            Button {
                                showingAddServer = true
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                }

                // Trailing: Account
                ToolbarItem(placement: .automatic) {
                    if authManager.isAuthenticated, let user = authManager.currentUser {
                        Menu {
                            Label(user.username, systemImage: "person.fill")
                            if let email = user.email {
                                Label(email, systemImage: "envelope")
                            }
                            Label(user.isAdmin ? "Admin" : "User", systemImage: "shield")
                            Divider()
                            Button {
                                showingProfile = true
                            } label: {
                                Label("Profile", systemImage: "person.text.rectangle")
                            }
                            Divider()
                            Button(role: .destructive) {
                                authManager.logout()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.fill")
                                Text(user.username)
                                    .font(.subheadline)
                            }
                        }
                    } else {
                        Button {
                            showingLoginSheet = true
                        } label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLoginSheet) {
                NavigationStack {
                    LoginView()
                        .navigationTitle("Sign In")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingLoginSheet = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingDashboard) {
                NavigationStack {
                    DashboardSheetView()
                        .navigationTitle("Dashboard")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingDashboard = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                NavigationStack {
                    AddServerView()
                        .navigationTitle("Add Server")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingAddServer = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationStack {
                    ProfileView()
                        .navigationTitle("Profile")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingProfile = false
                                }
                            }
                        }
                }
            }
            .task(id: serverManager.servers.count) {
                await serverManager.refreshStatuses()
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth {
                    showingLoginSheet = false
                }
            }
    }
}

// MARK: - Dashboard Sheet

struct DashboardSheetView: View {
    @State private var stats: AdminStats?
    @State private var health: HealthResponse?
    @State private var isLoading = true

    private let apiClient = APIClient.shared

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading...")
                    .padding(.top, 40)
            } else {
                VStack(spacing: 20) {
                    if let stats = stats {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 16) {
                            DashboardCard(title: "Repositories", value: "\(stats.totalRepositories)", icon: "folder.fill", color: .blue)
                            DashboardCard(title: "Artifacts", value: "\(stats.totalArtifacts)", icon: "doc.fill", color: .green)
                            DashboardCard(title: "Downloads", value: "\(stats.totalDownloads)", icon: "arrow.down.circle.fill", color: .orange)
                            DashboardCard(title: "Storage", value: formatBytes(stats.totalStorageBytes), icon: "externaldrive.fill", color: .purple)
                            DashboardCard(title: "Users", value: "\(stats.totalUsers)", icon: "person.2.fill", color: .cyan)
                            DashboardCard(title: "Active Peers", value: "\(stats.activePeers)", icon: "network", color: .mint)
                        }
                    }

                    if let health = health {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("System Health")
                                .font(.headline)

                            HStack {
                                Text("Status")
                                Spacer()
                                StatusDot(status: health.status)
                            }
                            if let version = health.version {
                                HStack {
                                    Text("Version")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(version)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let checks = health.checks {
                                ForEach(checks.sorted(by: { $0.key < $1.key }), id: \.key) { name, check in
                                    HStack {
                                        Text(name.capitalized)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        StatusDot(status: check.status)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = stats == nil && health == nil

        do { stats = try await apiClient.request("/api/v1/admin/stats") } catch {}
        do { health = try await apiClient.request("/health") } catch {}

        isLoading = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Server Sheet

struct AddServerView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var isTesting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Server Name", text: $name)
                    .autocorrectionDisabled()
                TextField("https://artifacts.example.com", text: $url)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
            } header: {
                Text("Server Details")
            } footer: {
                Text("Enter the base URL of your Artifact Keeper instance.")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button {
                    Task { await addServer() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isTesting ? "Testing Connection..." : "Add Server")
                    }
                }
                .disabled(name.isEmpty || url.isEmpty || isTesting)
            }
        }
    }

    private func addServer() async {
        isTesting = true
        errorMessage = nil

        let cleaned = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalURL = cleaned.hasSuffix("/") ? String(cleaned.dropLast()) : cleaned

        do {
            try await APIClient.shared.testConnection(to: finalURL)
            serverManager.addServer(name: name, url: finalURL)
            serverManager.switchTo(serverManager.servers.last!)
            dismiss()
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }
        isTesting = false
    }
}

extension View {
    func accountToolbar() -> some View {
        modifier(AccountToolbarModifier())
    }
}

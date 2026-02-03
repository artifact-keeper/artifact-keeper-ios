import SwiftUI

struct SettingsContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    @State private var showingAddServer = false
    @State private var serverToDelete: SavedServer?
    @State private var showingLoginSheet = false

    var body: some View {
        List {
            // Servers Section
            Section {
                ForEach(serverManager.servers) { server in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(server.name)
                                    .font(.body.weight(.medium))
                                if server.id == serverManager.activeServerId {
                                    Text("Active")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.green.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.green)
                                }
                            }
                            Text(server.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if server.id != serverManager.activeServerId {
                            Button("Connect") {
                                serverManager.switchTo(server)
                                authManager.logout()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            serverToDelete = server
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        if server.id != serverManager.activeServerId {
                            Button {
                                serverManager.switchTo(server)
                                authManager.logout()
                            } label: {
                                Label("Connect", systemImage: "arrow.right.circle")
                            }
                        }
                        Button(role: .destructive) {
                            serverToDelete = server
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showingAddServer = true
                } label: {
                    Label("Add Server", systemImage: "plus.circle")
                }
            } header: {
                Text("Servers")
            } footer: {
                Text("Manage your Artifact Keeper server connections. Swipe to remove.")
            }

            // Account Section
            Section("Account") {
                if authManager.isAuthenticated, let user = authManager.currentUser {
                    LabeledContent("Username", value: user.username)

                    if let email = user.email {
                        LabeledContent("Email", value: email)
                    }

                    LabeledContent("Role", value: user.isAdmin ? "Admin" : "User")

                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(.secondary)
                        Text("Not signed in")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingLoginSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Sign In")
                        }
                    }
                }
            }

            // About Section
            Section("About") {
                LabeledContent("App", value: "Artifact Keeper")
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
                LabeledContent("Platform", value: platformName)
            }
        }
        .alert("Remove Server", isPresented: Binding(
            get: { serverToDelete != nil },
            set: { if !$0 { serverToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { serverToDelete = nil }
            Button("Remove", role: .destructive) {
                if let server = serverToDelete {
                    serverManager.removeServer(server)
                    serverToDelete = nil
                }
            }
        } message: {
            if let server = serverToDelete {
                Text("Remove \"\(server.name)\" (\(server.url))? You can add it back later.")
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
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth {
                showingLoginSheet = false
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var platformName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Unknown"
        #endif
    }
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage(APIClient.serverURLKey) private var serverURL: String = ""
    @State private var editingURL: String = ""
    @State private var urlValidationError: String?
    @State private var showingSaveConfirmation = false
    @State private var showingLoginSheet = false
    @State private var showingDisconnectConfirmation = false

    private let apiClient = APIClient.shared

    var body: some View {
        NavigationStack {
            List {
                serverSection
                accountSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task {
                editingURL = serverURL
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
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth {
                    showingLoginSheet = false
                }
            }
        }
    }

    // MARK: - Server Section

    @ViewBuilder
    private var serverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://artifacts.example.com", text: $editingURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .onChange(of: editingURL) { _, newValue in
                        validateURL(newValue)
                    }

                if let error = urlValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)

            Button {
                saveServerURL()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Save Server URL")
                }
            }
            .disabled(urlValidationError != nil || editingURL == serverURL)

            if showingSaveConfirmation {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Server URL updated")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Button(role: .destructive) {
                showingDisconnectConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disconnect Server")
                }
            }
            .alert("Disconnect Server", isPresented: $showingDisconnectConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    disconnectServer()
                }
            } message: {
                Text("This will clear the server URL and return you to the setup screen. You can reconnect at any time.")
            }
        } header: {
            Text("Server")
        } footer: {
            Text("The base URL of your Artifact Keeper server. Changes require restarting data loads.")
        }
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if authManager.isAuthenticated, let user = authManager.currentUser {
                LabeledContent("Username", value: user.username)

                if let email = user.email {
                    LabeledContent("Email", value: email)
                }

                LabeledContent("Role", value: user.isAdmin ? "Admin" : "User")

                Button(role: .destructive) {
                    authManager.logout()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                }
            } else {
                HStack {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("Not signed in")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingLoginSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Sign In")
                    }
                }
            }
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: "Artifact Keeper")
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
            LabeledContent("Platform", value: platformName)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var platformName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Unknown"
        #endif
    }

    private func validateURL(_ urlString: String) {
        if urlString.isEmpty {
            urlValidationError = "URL cannot be empty"
            return
        }

        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            urlValidationError = "Enter a valid URL (http:// or https://)"
            return
        }

        urlValidationError = nil
    }

    private func disconnectServer() {
        serverURL = ""
        editingURL = ""
        Task {
            await apiClient.updateBaseURL("")
        }
        authManager.logout()
    }

    private func saveServerURL() {
        let trimmed = editingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove trailing slash
        let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        editingURL = cleaned
        serverURL = cleaned
        Task {
            await apiClient.updateBaseURL(cleaned)
        }
        showingSaveConfirmation = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            showingSaveConfirmation = false
        }
    }
}

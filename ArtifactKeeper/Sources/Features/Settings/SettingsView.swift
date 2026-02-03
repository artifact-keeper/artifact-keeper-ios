import SwiftUI

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

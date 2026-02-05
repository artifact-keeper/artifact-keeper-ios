import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab()
                .tabItem { Label("General", systemImage: "person") }
                .tag(0)
            ApiKeysTab()
                .tabItem { Label("API Keys", systemImage: "key") }
                .tag(1)
            AccessTokensTab()
                .tabItem { Label("Access Tokens", systemImage: "shield") }
                .tag(2)
            SecurityTab()
                .tabItem { Label("Security", systemImage: "lock") }
                .tag(3)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var profile: ProfileResponse?
    @State private var displayName = ""
    @State private var email = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var success = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            Section("Profile Information") {
                LabeledContent("Username") {
                    Text(profile?.username ?? authManager.currentUser?.username ?? "—")
                        .foregroundStyle(.secondary)
                }

                TextField("Display Name", text: $displayName)
                    .autocorrectionDisabled()
                TextField("Email", text: $email)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif

                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                if success {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Profile updated").font(.caption).foregroundStyle(.green)
                    }
                }

                Button {
                    Task { await saveProfile() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().controlSize(.small) }
                        Text("Save Changes")
                    }
                }
                .disabled(isSaving)
            }
        }
        .formStyle(.grouped)
        .task { await loadProfile() }
    }

    private func loadProfile() async {
        isLoading = true
        do {
            let p = try await api.getProfile()
            profile = p
            displayName = p.displayName ?? ""
            email = p.email
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func saveProfile() async {
        isSaving = true
        error = nil
        success = false
        do {
            let updated = try await api.updateProfile(
                displayName: displayName.isEmpty ? nil : displayName,
                email: email.isEmpty ? nil : email
            )
            profile = updated
            success = true
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - API Keys Tab

private struct ApiKeysTab: View {
    @State private var keys: [ApiKey] = []
    @State private var isLoading = true
    @State private var error: String?

    // Create
    @State private var showCreate = false
    @State private var newKeyName = ""
    @State private var newKeyExpiry = 90
    @State private var newKeyScopes: Set<String> = ["read"]
    @State private var createdKey: String?
    @State private var isCreating = false

    // Delete
    @State private var keyToDelete: ApiKey?

    private let api = APIClient.shared

    private let expiryOptions: [(String, Int)] = [
        ("30 days", 30), ("60 days", 60), ("90 days", 90),
        ("180 days", 180), ("1 year", 365), ("Never", 0),
    ]

    var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if keys.isEmpty {
                    ContentUnavailableView(
                        "No API Keys",
                        systemImage: "key",
                        description: Text("Create an API key for programmatic access.")
                    )
                } else {
                    ForEach(keys) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(key.name).font(.headline)
                                Spacer()
                                Button(role: .destructive) {
                                    keyToDelete = key
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            Text(key.keyPrefix + "...").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                            if let scopes = key.scopes, !scopes.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(scopes, id: \.self) { scope in
                                        Text(scope)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.secondary.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                            Text("Created \(formattedDate(key.createdAt))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("API Keys")
                    Spacer()
                    Button {
                        showCreate = true
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let createdKey {
                Section("New Key Created") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Copy this key now — it won't be shown again.")
                            .font(.caption).foregroundStyle(.orange)
                        HStack {
                            Text(createdKey)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button {
                                copyToClipboard(createdKey)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        Button("Dismiss") {
                            self.createdKey = nil
                        }
                    }
                }
            }
        }
        .task { await loadKeys() }
        .sheet(isPresented: $showCreate) {
            createKeySheet
        }
        .alert("Revoke API Key?", isPresented: .init(
            get: { keyToDelete != nil },
            set: { if !$0 { keyToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke", role: .destructive) {
                if let key = keyToDelete {
                    Task { await deleteKey(key.id) }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var createKeySheet: some View {
        NavigationStack {
            Form {
                TextField("Key Name", text: $newKeyName)
                    .autocorrectionDisabled()

                Picker("Expires", selection: $newKeyExpiry) {
                    ForEach(expiryOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Section("Scopes") {
                    ForEach(["read", "write", "delete", "admin"], id: \.self) { scope in
                        Toggle(scope.capitalized, isOn: Binding(
                            get: { newKeyScopes.contains(scope) },
                            set: { if $0 { newKeyScopes.insert(scope) } else { newKeyScopes.remove(scope) } }
                        ))
                    }
                }

                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create API Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createKey() }
                    } label: {
                        if isCreating { ProgressView().controlSize(.small) }
                        else { Text("Create") }
                    }
                    .disabled(newKeyName.isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 300)
    }

    private func loadKeys() async {
        isLoading = true
        do { keys = try await api.listApiKeys() } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    private func createKey() async {
        isCreating = true
        error = nil
        do {
            let result = try await api.createApiKey(
                name: newKeyName,
                scopes: Array(newKeyScopes),
                expiresInDays: newKeyExpiry == 0 ? nil : newKeyExpiry
            )
            createdKey = result.key
            newKeyName = ""
            newKeyScopes = ["read"]
            newKeyExpiry = 90
            showCreate = false
            await loadKeys()
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }

    private func deleteKey(_ id: String) async {
        do {
            try await api.deleteApiKey(id)
            keyToDelete = nil
            await loadKeys()
        } catch {}
    }
}

// MARK: - Access Tokens Tab

private struct AccessTokensTab: View {
    @State private var tokens: [AccessToken] = []
    @State private var isLoading = true
    @State private var error: String?

    // Create
    @State private var showCreate = false
    @State private var newTokenName = ""
    @State private var newTokenExpiry = 90
    @State private var newTokenScopes: Set<String> = ["read"]
    @State private var createdToken: String?
    @State private var isCreating = false

    // Delete
    @State private var tokenToDelete: AccessToken?

    private let api = APIClient.shared

    private let expiryOptions: [(String, Int)] = [
        ("30 days", 30), ("60 days", 60), ("90 days", 90),
        ("180 days", 180), ("1 year", 365), ("Never", 0),
    ]

    var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if tokens.isEmpty {
                    ContentUnavailableView(
                        "No Access Tokens",
                        systemImage: "shield",
                        description: Text("Create an access token for CLI or CI/CD use.")
                    )
                } else {
                    ForEach(tokens) { token in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(token.name).font(.headline)
                                Spacer()
                                Button(role: .destructive) {
                                    tokenToDelete = token
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            Text(token.tokenPrefix + "...").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                            if let scopes = token.scopes, !scopes.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(scopes, id: \.self) { scope in
                                        Text(scope)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.secondary.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                            Text("Created \(formattedDate(token.createdAt))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Access Tokens")
                    Spacer()
                    Button {
                        showCreate = true
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let createdToken {
                Section("New Token Created") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Copy this token now — it won't be shown again.")
                            .font(.caption).foregroundStyle(.orange)
                        HStack {
                            Text(createdToken)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button {
                                copyToClipboard(createdToken)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        Button("Dismiss") {
                            self.createdToken = nil
                        }
                    }
                }
            }
        }
        .task { await loadTokens() }
        .sheet(isPresented: $showCreate) {
            createTokenSheet
        }
        .alert("Revoke Access Token?", isPresented: .init(
            get: { tokenToDelete != nil },
            set: { if !$0 { tokenToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke", role: .destructive) {
                if let token = tokenToDelete {
                    Task { await deleteToken(token.id) }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var createTokenSheet: some View {
        NavigationStack {
            Form {
                TextField("Token Name", text: $newTokenName)
                    .autocorrectionDisabled()

                Picker("Expires", selection: $newTokenExpiry) {
                    ForEach(expiryOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }

                Section("Scopes") {
                    ForEach(["read", "write", "delete", "admin"], id: \.self) { scope in
                        Toggle(scope.capitalized, isOn: Binding(
                            get: { newTokenScopes.contains(scope) },
                            set: { if $0 { newTokenScopes.insert(scope) } else { newTokenScopes.remove(scope) } }
                        ))
                    }
                }

                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Access Token")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createToken() }
                    } label: {
                        if isCreating { ProgressView().controlSize(.small) }
                        else { Text("Create") }
                    }
                    .disabled(newTokenName.isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 300)
    }

    private func loadTokens() async {
        isLoading = true
        do { tokens = try await api.listAccessTokens() } catch { self.error = error.localizedDescription }
        isLoading = false
    }

    private func createToken() async {
        isCreating = true
        error = nil
        do {
            let result = try await api.createAccessToken(
                name: newTokenName,
                scopes: Array(newTokenScopes),
                expiresInDays: newTokenExpiry == 0 ? nil : newTokenExpiry
            )
            createdToken = result.token
            newTokenName = ""
            newTokenScopes = ["read"]
            newTokenExpiry = 90
            showCreate = false
            await loadTokens()
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }

    private func deleteToken(_ id: String) async {
        do {
            try await api.deleteAccessToken(id)
            tokenToDelete = nil
            await loadTokens()
        } catch {}
    }
}

// MARK: - Security Tab

private struct SecurityTab: View {
    @EnvironmentObject var authManager: AuthManager

    // Password change
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordLoading = false
    @State private var passwordError: String?
    @State private var passwordSuccess = false

    // TOTP setup flow
    @State private var totpSetupResponse: TotpSetupResponse?
    @State private var totpVerificationCode = ""
    @State private var totpBackupCodes: [String]?
    @State private var totpSetupLoading = false
    @State private var totpError: String?

    // TOTP disable flow
    @State private var showingDisableTotp = false
    @State private var disablePassword = ""
    @State private var disableCode = ""
    @State private var disableLoading = false

    private let api = APIClient.shared

    var body: some View {
        Form {
            changePasswordSection
            twoFactorSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Change Password

    @ViewBuilder
    private var changePasswordSection: some View {
        Section {
            SecureField("Current Password", text: $currentPassword)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            SecureField("New Password", text: $newPassword)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            SecureField("Confirm New Password", text: $confirmPassword)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if let error = passwordError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if passwordSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Password changed successfully").font(.caption).foregroundStyle(.green)
                }
            }

            Button {
                Task { await changePassword() }
            } label: {
                HStack {
                    if passwordLoading { ProgressView().controlSize(.small) }
                    Text("Change Password")
                }
            }
            .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword || passwordLoading)
        } header: {
            Text("Change Password")
        }
    }

    private func changePassword() async {
        guard let user = authManager.currentUser else { return }
        passwordLoading = true
        passwordError = nil
        passwordSuccess = false
        do {
            try await api.changeUserPassword(userId: user.id, currentPassword: currentPassword, newPassword: newPassword)
            passwordSuccess = true
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        } catch {
            passwordError = error.localizedDescription
        }
        passwordLoading = false
    }

    // MARK: - Two-Factor Authentication

    @ViewBuilder
    private var twoFactorSection: some View {
        Section {
            if let user = authManager.currentUser, user.totpEnabled {
                totpEnabledContent
            } else if let backupCodes = totpBackupCodes {
                backupCodesContent(backupCodes)
            } else if let setup = totpSetupResponse {
                totpSetupContent(setup)
            } else {
                totpDisabledContent
            }

            if let error = totpError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Two-Factor Authentication")
        }
    }

    @ViewBuilder
    private var totpEnabledContent: some View {
        HStack {
            Text("Status")
            Spacer()
            Text("Enabled")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        }

        if showingDisableTotp {
            SecureField("Password", text: $disablePassword)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            TextField("TOTP Code", text: $disableCode)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)
                #endif

            Button {
                Task { await disableTotp() }
            } label: {
                HStack {
                    if disableLoading { ProgressView().controlSize(.small) }
                    Text("Confirm Disable")
                }
            }
            .disabled(disablePassword.isEmpty || disableCode.isEmpty || disableLoading)

            Button("Cancel") {
                showingDisableTotp = false
                disablePassword = ""
                disableCode = ""
            }
        } else {
            Button(role: .destructive) {
                showingDisableTotp = true
            } label: {
                Label("Disable 2FA", systemImage: "lock.slash")
            }
        }
    }

    @ViewBuilder
    private var totpDisabledContent: some View {
        HStack {
            Text("Status")
            Spacer()
            Text("Disabled")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }

        Button {
            Task { await setupTotp() }
        } label: {
            HStack {
                if totpSetupLoading { ProgressView().controlSize(.small) }
                Label("Enable 2FA", systemImage: "lock.shield")
            }
        }
        .disabled(totpSetupLoading)
    }

    @ViewBuilder
    private func totpSetupContent(_ setup: TotpSetupResponse) -> some View {
        VStack(spacing: 16) {
            Text("Scan this QR code with your authenticator app:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            generateQRCode(from: setup.qrCodeUrl)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text("Manual entry key:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(setup.secret)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        copyToClipboard(setup.secret)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)

        TextField("6-digit verification code", text: $totpVerificationCode)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.numberPad)
            #endif

        Button {
            Task { await enableTotp() }
        } label: {
            HStack {
                if totpSetupLoading { ProgressView().controlSize(.small) }
                Text("Verify and Enable")
            }
        }
        .disabled(totpVerificationCode.isEmpty || totpSetupLoading)

        Button("Cancel") {
            totpSetupResponse = nil
            totpVerificationCode = ""
            totpError = nil
        }
    }

    @ViewBuilder
    private func backupCodesContent(_ codes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Two-factor authentication enabled!").font(.headline)
            }

            Text("Save these backup codes in a secure location. Each code can only be used once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(codes, id: \.self) { code in
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                Button {
                    copyToClipboard(codes.joined(separator: "\n"))
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                }

                Button("Done") {
                    totpBackupCodes = nil
                    totpSetupResponse = nil
                    totpVerificationCode = ""
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - TOTP Actions

    private func setupTotp() async {
        totpSetupLoading = true
        totpError = nil
        do { totpSetupResponse = try await api.totpSetup() }
        catch { totpError = error.localizedDescription }
        totpSetupLoading = false
    }

    private func enableTotp() async {
        totpSetupLoading = true
        totpError = nil
        do {
            let response = try await api.totpEnable(code: totpVerificationCode)
            totpBackupCodes = response.backupCodes
        } catch { totpError = error.localizedDescription }
        totpSetupLoading = false
    }

    private func disableTotp() async {
        disableLoading = true
        totpError = nil
        do {
            try await api.totpDisable(password: disablePassword, code: disableCode)
            showingDisableTotp = false
            disablePassword = ""
            disableCode = ""
        } catch { totpError = error.localizedDescription }
        disableLoading = false
    }

    // MARK: - QR Code Generator

    private func generateQRCode(from string: String) -> Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            return Image(systemName: "xmark.circle")
        }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return Image(systemName: "xmark.circle")
        }

        #if os(iOS)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #else
        return Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
        #endif
    }
}

// MARK: - Helpers

private func formattedDate(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: isoString) {
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: isoString) {
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
    return isoString
}

private func copyToClipboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #else
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}

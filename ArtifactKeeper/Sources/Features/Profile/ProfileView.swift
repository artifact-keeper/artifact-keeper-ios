import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
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

    private let apiClient = APIClient.shared

    var body: some View {
        List {
            accountSection
            changePasswordSection
            twoFactorSection
        }
        .navigationTitle("Profile")
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        if let user = authManager.currentUser {
            Section("Account") {
                LabeledContent("Username", value: user.username)
                if let email = user.email {
                    LabeledContent("Email", value: email)
                }
                LabeledContent("Role", value: user.isAdmin ? "Admin" : "User")
            }
        }
    }

    // MARK: - Change Password Section

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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if passwordSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Password changed successfully")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Button {
                Task { await changePassword() }
            } label: {
                HStack {
                    if passwordLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Change Password")
                }
            }
            .disabled(changePasswordDisabled)
        } header: {
            Text("Change Password")
        }
    }

    private var changePasswordDisabled: Bool {
        currentPassword.isEmpty
            || newPassword.isEmpty
            || confirmPassword.isEmpty
            || newPassword != confirmPassword
            || passwordLoading
    }

    private func changePassword() async {
        guard let user = authManager.currentUser else { return }
        passwordLoading = true
        passwordError = nil
        passwordSuccess = false

        do {
            try await apiClient.changeUserPassword(
                userId: user.id,
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            passwordSuccess = true
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        } catch {
            passwordError = error.localizedDescription
        }

        passwordLoading = false
    }

    // MARK: - Two-Factor Authentication Section

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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
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
                    if disableLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
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
                if totpSetupLoading {
                    ProgressView()
                        .controlSize(.small)
                }
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
                Text(setup.secret)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
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
                if totpSetupLoading {
                    ProgressView()
                        .controlSize(.small)
                }
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
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Two-factor authentication enabled!")
                    .font(.headline)
            }

            Text("Save these backup codes in a secure location. Each code can only be used once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                ForEach(codes, id: \.self) { code in
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.vertical, 4)

        Button("Done") {
            totpBackupCodes = nil
            totpSetupResponse = nil
            totpVerificationCode = ""
        }
    }

    // MARK: - TOTP Actions

    private func setupTotp() async {
        totpSetupLoading = true
        totpError = nil

        do {
            totpSetupResponse = try await apiClient.totpSetup()
        } catch {
            totpError = error.localizedDescription
        }

        totpSetupLoading = false
    }

    private func enableTotp() async {
        totpSetupLoading = true
        totpError = nil

        do {
            let response = try await apiClient.totpEnable(code: totpVerificationCode)
            totpBackupCodes = response.backupCodes
        } catch {
            totpError = error.localizedDescription
        }

        totpSetupLoading = false
    }

    private func disableTotp() async {
        disableLoading = true
        totpError = nil

        do {
            try await apiClient.totpDisable(password: disablePassword, code: disableCode)
            showingDisableTotp = false
            disablePassword = ""
            disableCode = ""
        } catch {
            totpError = error.localizedDescription
        }

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

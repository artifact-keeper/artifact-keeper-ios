import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword && !currentPassword.isEmpty
    }

    private var validationMessage: String? {
        if !newPassword.isEmpty && newPassword.count < 8 {
            return "New password must be at least 8 characters"
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return "Passwords do not match"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(.blue.gradient)

                Text("Change Password")
                    .font(.largeTitle.bold())

                Text("You must change your password before continuing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                SecureField("Current Password", text: $currentPassword)
                    .textFieldStyle(.roundedBorder)

                SecureField("New Password", text: $newPassword)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm New Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)

                if let validation = validationMessage {
                    Text(validation)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await changePassword()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Change Password")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValid || isLoading)
            }
            .frame(maxWidth: 320)

            Spacer()
            Spacer()
        }
        .padding()
    }

    private func changePassword() async {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "User ID not available"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let body = ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            try await APIClient.shared.requestVoid(
                "/api/v1/admin/users/\(userId)/password",
                method: "POST",
                body: body
            )
            authManager.mustChangePassword = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

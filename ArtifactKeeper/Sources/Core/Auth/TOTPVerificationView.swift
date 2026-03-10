import SwiftUI

struct TOTPVerificationView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var code = ""
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(.blue.gradient)

                Text("Two-Factor Authentication")
                    .font(.title2.bold())

                Text("Enter the 6-digit code from your authenticator app to complete sign-in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                TextField("000000", text: $code)
                    .font(.system(.title, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($isCodeFieldFocused)
                    .onChange(of: code) { _, newValue in
                        // Allow only digits, max 6
                        let filtered = newValue.filter(\.isNumber)
                        if filtered.count > 6 {
                            code = String(filtered.prefix(6))
                        } else if filtered != newValue {
                            code = filtered
                        }
                    }
                    .onSubmit {
                        if code.count == 6 {
                            submitCode()
                        }
                    }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    submitCode()
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Verify")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(code.count != 6 || authManager.isLoading)

                Button("Cancel") {
                    authManager.totpRequired = false
                    authManager.totpToken = nil
                    authManager.errorMessage = nil
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280)

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            isCodeFieldFocused = true
        }
    }

    private func submitCode() {
        guard code.count == 6 else { return }
        Task {
            await authManager.verifyTotp(code: code)
        }
    }
}

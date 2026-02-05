import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(.blue.gradient)
                
                Text("Artifact Keeper")
                    .font(.largeTitle.bold())
                
                Text(authManager.setupRequired ? "Complete first-time setup" : "Sign in to your account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if authManager.setupRequired {
                VStack(alignment: .leading, spacing: 8) {
                    Label("First-Time Setup", systemImage: "terminal")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text("A random admin password was generated. Retrieve it from the server:")
                        .font(.subheadline)

                    Text("docker exec artifact-keeper-backend cat /data/storage/admin.password")
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Log in with username **admin** and the password from the file.")
                        .font(.subheadline)
                }
                .padding()
                .background(.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: 320)
            }

            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Button {
                    Task {
                        await authManager.login(username: username, password: password)
                    }
                } label: {
                    if authManager.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(username.isEmpty || password.isEmpty || authManager.isLoading)
            }
            .frame(maxWidth: 320)
            
            Spacer()
            Spacer()
        }
        .padding()
        .task {
            await authManager.checkSetupStatus()
            if authManager.setupRequired {
                username = "admin"
            }
        }
    }
}

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
                
                Text("Sign in to your account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
    }
}

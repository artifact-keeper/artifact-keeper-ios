import SwiftUI

struct AccountToolbarModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingLoginSheet = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if authManager.isAuthenticated, let user = authManager.currentUser {
                        Menu {
                            Label(user.username, systemImage: "person.fill")
                            if let email = user.email {
                                Label(email, systemImage: "envelope")
                            }
                            Label(user.isAdmin ? "Admin" : "User", systemImage: "shield")
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
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth {
                    showingLoginSheet = false
                }
            }
    }
}

extension View {
    func accountToolbar() -> some View {
        modifier(AccountToolbarModifier())
    }
}

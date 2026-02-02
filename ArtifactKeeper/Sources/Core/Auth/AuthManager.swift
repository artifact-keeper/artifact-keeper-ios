import SwiftUI
import Foundation

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: LoginResponse = try await apiClient.request(
                "/api/v1/auth/login",
                method: "POST",
                body: LoginRequest(username: username, password: password)
            )
            
            await apiClient.setToken(response.accessToken)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        Task {
            await apiClient.setToken(nil)
        }
        currentUser = nil
        isAuthenticated = false
    }
}

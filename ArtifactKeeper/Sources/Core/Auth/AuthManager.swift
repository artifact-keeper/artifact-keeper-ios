import SwiftUI
import Foundation

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?

    func login(username: String, password: String) async throws {
        // TODO: Implement login against backend API
    }

    func logout() {
        accessToken = nil
        isAuthenticated = false
    }
}

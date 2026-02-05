import SwiftUI
import Foundation

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var mustChangePassword = false
    @Published var currentUser: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var setupRequired = false

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

            // Decode user info from JWT payload
            if let user = Self.decodeJWT(response.accessToken) {
                currentUser = user
            }
            isAuthenticated = true

            if response.mustChangePassword == true {
                mustChangePassword = true
            }
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
        mustChangePassword = false
    }

    func checkSetupStatus() async {
        do {
            let status: SetupStatusResponse = try await apiClient.request("/api/v1/setup/status")
            setupRequired = status.setupRequired
        } catch {
            setupRequired = false
        }
    }

    func handleServerSwitch() {
        logout()
    }

    /// Decode user info from JWT access token payload (base64 middle segment)
    private static func decodeJWT(_ token: String) -> UserInfo? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var base64 = String(segments[1])
        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(UserInfo.self, from: data)
    }
}

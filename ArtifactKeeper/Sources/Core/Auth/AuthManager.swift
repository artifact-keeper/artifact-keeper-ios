import SwiftUI
import Foundation
import ArtifactKeeperClient
import OpenAPIRuntime

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var mustChangePassword = false
    @Published var currentUser: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var setupRequired = false
    @Published var totpRequired = false
    @Published var totpToken: String?

    private let apiClient = APIClient.shared
    private let sdkClient = SDKClient.shared

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let client = await sdkClient.client
            let response = try await client.login(
                body: .json(.init(password: password, username: username))
            )
            let data = try response.ok.body.json

            // Check if TOTP verification is required
            if data.totp_required == true {
                totpRequired = true
                totpToken = data.totp_token
                isLoading = false
                return
            }

            await apiClient.setToken(data.access_token)

            // Decode user info from JWT payload
            if let user = Self.decodeJWT(data.access_token) {
                currentUser = user
            }
            isAuthenticated = true

            if data.must_change_password {
                mustChangePassword = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func verifyTotp(code: String) async {
        guard let token = totpToken else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response: LoginResponse = try await apiClient.totpVerify(totpToken: token, code: code)

            await apiClient.setToken(response.accessToken)

            if let user = Self.decodeJWT(response.accessToken) {
                currentUser = user
            }
            isAuthenticated = true
            totpRequired = false
            self.totpToken = nil

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
        totpRequired = false
        totpToken = nil
    }

    func checkSetupStatus() async {
        do {
            let client = await sdkClient.client
            let response = try await client.setup_status()
            let data = try response.ok.body.json
            setupRequired = data.setup_required
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

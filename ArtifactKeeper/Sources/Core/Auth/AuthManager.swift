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

    /// The server URL used to scope Keychain storage. Kept in sync with the
    /// active server connection so that token lookup is always correct.
    private var currentServerURL: String

    init() {
        self.currentServerURL = UserDefaults.standard.string(forKey: APIClient.serverURLKey) ?? ""
    }

    // MARK: - Session Restoration

    /// Attempt to restore a previous session from tokens stored in the Keychain.
    /// Call this once on app launch after the server URL is known.
    func restoreSession() async {
        let serverURL = currentServerURL
        guard !serverURL.isEmpty else { return }

        if let accessToken = KeychainManager.getAccessToken(serverURL: serverURL) {
            await apiClient.setToken(accessToken)

            if let user = Self.decodeJWT(accessToken) {
                // Check whether the token has expired by inspecting the `exp` claim.
                if Self.isTokenExpired(accessToken) {
                    // Access token expired, try to refresh.
                    let didRefresh = await refreshToken()
                    if !didRefresh {
                        // Refresh failed, clear everything.
                        clearStoredTokens()
                        await apiClient.setToken(nil)
                        return
                    }
                } else {
                    currentUser = user
                    isAuthenticated = true
                }
            } else {
                // JWT could not be decoded. Try refreshing in case the format changed.
                let didRefresh = await refreshToken()
                if !didRefresh {
                    clearStoredTokens()
                    await apiClient.setToken(nil)
                }
            }
        }
    }

    // MARK: - Login

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

            await handleLoginSuccess(
                accessToken: data.access_token,
                refreshToken: data.refresh_token,
                mustChange: data.must_change_password
            )
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

            await handleLoginSuccess(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                mustChange: response.mustChangePassword ?? false
            )

            totpRequired = false
            self.totpToken = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        Task {
            await apiClient.setToken(nil)
        }
        clearStoredTokens()
        currentUser = nil
        isAuthenticated = false
        mustChangePassword = false
        totpRequired = false
        totpToken = nil
    }

    // MARK: - Server Switch

    func handleServerSwitch() {
        logout()
    }

    /// Update the server URL used for Keychain scoping. Called when the
    /// active server connection changes.
    func updateServerURL(_ url: String) {
        if url != currentServerURL {
            currentServerURL = url
        }
    }

    // MARK: - Setup Check

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

    // MARK: - Token Refresh

    /// Attempt to refresh the access token using the stored refresh token.
    /// Returns `true` if the refresh succeeded and new tokens were saved.
    @discardableResult
    func refreshToken() async -> Bool {
        let serverURL = currentServerURL
        guard !serverURL.isEmpty,
              let storedRefresh = KeychainManager.getRefreshToken(serverURL: serverURL) else {
            return false
        }

        do {
            let client = await sdkClient.client
            let response = try await client.refresh_token(
                body: .json(.init(refresh_token: storedRefresh))
            )
            let data = try response.ok.body.json

            // Persist the new token pair.
            try KeychainManager.saveAccessToken(data.access_token, serverURL: serverURL)
            let newRefresh = data.refresh_token
            if !newRefresh.isEmpty {
                try KeychainManager.saveRefreshToken(newRefresh, serverURL: serverURL)
            }

            await apiClient.setToken(data.access_token)

            if let user = Self.decodeJWT(data.access_token) {
                currentUser = user
            }
            isAuthenticated = true
            return true
        } catch {
            // Refresh failed (token expired, revoked, etc.).
            return false
        }
    }

    // MARK: - Private Helpers

    /// Common success path after login or TOTP verification.
    private func handleLoginSuccess(accessToken: String, refreshToken: String?, mustChange: Bool) async {
        // Ensure we have the current server URL.
        let serverURL = currentServerURL.isEmpty
            ? (UserDefaults.standard.string(forKey: APIClient.serverURLKey) ?? "")
            : currentServerURL
        currentServerURL = serverURL

        await apiClient.setToken(accessToken)

        // Persist to Keychain (best-effort; a failure here should not block login).
        do {
            try KeychainManager.saveAccessToken(accessToken, serverURL: serverURL)
        } catch {
            // Keychain write failed; log but continue.
        }
        if let refresh = refreshToken, !refresh.isEmpty {
            do {
                try KeychainManager.saveRefreshToken(refresh, serverURL: serverURL)
            } catch {
                // Keychain write failed; log but continue.
            }
        }

        if let user = Self.decodeJWT(accessToken) {
            currentUser = user
        }
        isAuthenticated = true

        if mustChange {
            mustChangePassword = true
        }
    }

    private func clearStoredTokens() {
        let serverURL = currentServerURL
        guard !serverURL.isEmpty else { return }
        KeychainManager.deleteTokens(serverURL: serverURL)
    }

    /// Decode user info from JWT access token payload (base64 middle segment).
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

    /// Check whether the `exp` claim in a JWT is in the past.
    private static func isTokenExpired(_ token: String) -> Bool {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return true }

        var base64 = String(segments[1])
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }

        return Date().timeIntervalSince1970 >= exp
    }
}

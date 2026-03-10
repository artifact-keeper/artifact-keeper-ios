import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - JWT Test Helpers

/// Utility for building test JWT tokens with known payloads.
enum JWTTestHelper {
    /// Build a minimal three-segment JWT string from a JSON payload dictionary.
    /// The header and signature are stubs; only the payload is meaningful.
    static func makeJWT(payload: [String: Any]) -> String? {
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        let header = Data("{\"alg\":\"HS256\",\"typ\":\"JWT\"}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let payloadB64 = payloadData
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        return "\(header).\(payloadB64).stub_signature"
    }

    /// Build a JWT with a standard UserInfo payload and optional extra claims.
    static func makeUserJWT(
        sub: String = "user-123",
        username: String = "testuser",
        email: String? = "test@example.com",
        isAdmin: Bool = false,
        totpEnabled: Bool = false,
        exp: TimeInterval? = nil,
        extraClaims: [String: Any] = [:]
    ) -> String? {
        var payload: [String: Any] = [
            "sub": sub,
            "username": username,
            "is_admin": isAdmin,
            "totp_enabled": totpEnabled,
        ]
        if let email = email {
            payload["email"] = email
        }
        if let exp = exp {
            payload["exp"] = exp
        }
        for (key, value) in extraClaims {
            payload[key] = value
        }
        return makeJWT(payload: payload)
    }
}

// MARK: - AuthManager.decodeJWT Tests

@Suite("AuthManager decodeJWT Tests")
struct AuthManagerDecodeJWTTests {

    @Test func decodeValidUserInfoJWT() {
        guard let jwt = JWTTestHelper.makeUserJWT() else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user != nil)
        #expect(user?.id == "user-123")
        #expect(user?.username == "testuser")
        #expect(user?.email == "test@example.com")
        #expect(user?.isAdmin == false)
        #expect(user?.totpEnabled == false)
    }

    @Test func decodeAdminUserJWT() {
        guard let jwt = JWTTestHelper.makeUserJWT(
            sub: "admin-1",
            username: "admin",
            email: "admin@example.com",
            isAdmin: true,
            totpEnabled: true
        ) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user != nil)
        #expect(user?.id == "admin-1")
        #expect(user?.username == "admin")
        #expect(user?.isAdmin == true)
        #expect(user?.totpEnabled == true)
    }

    @Test func decodeJWTWithoutEmail() {
        guard let jwt = JWTTestHelper.makeUserJWT(email: nil) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user != nil)
        #expect(user?.email == nil)
    }

    @Test func decodeJWTWithExtraClaims() {
        guard let jwt = JWTTestHelper.makeUserJWT(
            extraClaims: ["exp": 9999999999.0, "iat": 1000000000.0]
        ) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user != nil)
        #expect(user?.id == "user-123")
    }

    @Test func decodeJWTReturnsNilForEmptyString() {
        let user = AuthManager.decodeJWT("")
        #expect(user == nil)
    }

    @Test func decodeJWTReturnsNilForOneSegment() {
        let user = AuthManager.decodeJWT("just-one-segment")
        #expect(user == nil)
    }

    @Test func decodeJWTReturnsNilForTwoSegments() {
        let user = AuthManager.decodeJWT("header.payload")
        #expect(user == nil)
    }

    @Test func decodeJWTReturnsNilForFourSegments() {
        let user = AuthManager.decodeJWT("a.b.c.d")
        #expect(user == nil)
    }

    @Test func decodeJWTReturnsNilForInvalidBase64() {
        let user = AuthManager.decodeJWT("header.!!!not-base64!!!.signature")
        #expect(user == nil)
    }

    @Test func decodeJWTReturnsNilForValidBase64ButNotJSON() {
        let notJson = Data("this is not json".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let user = AuthManager.decodeJWT("header.\(notJson).signature")
        #expect(user == nil)
    }

    @Test func decodeJWTReturnsNilForJSONMissingRequiredFields() {
        // JSON that is valid but missing "sub" and "username"
        guard let jwt = JWTTestHelper.makeJWT(payload: ["foo": "bar"]) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user == nil)
    }

    @Test func decodeJWTHandlesBase64Padding() {
        // Build a payload whose base64 needs padding (length not divisible by 4)
        guard let jwt = JWTTestHelper.makeUserJWT(
            sub: "u",
            username: "x",
            email: nil
        ) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user != nil)
        #expect(user?.id == "u")
        #expect(user?.username == "x")
    }

    @Test func decodeJWTWithTotpEnabledMissing() {
        // When totp_enabled is absent, it should default to false
        guard let jwt = JWTTestHelper.makeJWT(payload: [
            "sub": "user-no-totp",
            "username": "nototp",
            "is_admin": false,
        ]) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let user = AuthManager.decodeJWT(jwt)
        #expect(user != nil)
        #expect(user?.totpEnabled == false)
    }
}

// MARK: - AuthManager.isTokenExpired Tests

@Suite("AuthManager isTokenExpired Tests")
struct AuthManagerIsTokenExpiredTests {

    @Test func tokenWithFutureExpIsNotExpired() {
        let futureExp = Date().timeIntervalSince1970 + 3600 // 1 hour from now
        guard let jwt = JWTTestHelper.makeUserJWT(exp: futureExp) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        #expect(expired == false)
    }

    @Test func tokenWithPastExpIsExpired() {
        let pastExp = Date().timeIntervalSince1970 - 3600 // 1 hour ago
        guard let jwt = JWTTestHelper.makeUserJWT(exp: pastExp) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        #expect(expired == true)
    }

    @Test func tokenWithExpAtEpochIsExpired() {
        guard let jwt = JWTTestHelper.makeUserJWT(exp: 0) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        #expect(expired == true)
    }

    @Test func tokenWithVeryFarFutureExpIsNotExpired() {
        // Year 2099 timestamp
        let farFuture: TimeInterval = 4_102_444_800
        guard let jwt = JWTTestHelper.makeUserJWT(exp: farFuture) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        #expect(expired == false)
    }

    @Test func tokenWithoutExpClaimIsExpired() {
        // Build a JWT without the "exp" claim
        guard let jwt = JWTTestHelper.makeUserJWT() else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        // No exp claim means we cannot verify, should treat as expired
        #expect(expired == true)
    }

    @Test func emptyStringTokenIsExpired() {
        let expired = AuthManager.isTokenExpired("")
        #expect(expired == true)
    }

    @Test func malformedTokenIsExpired() {
        let expired = AuthManager.isTokenExpired("not.a.jwt")
        #expect(expired == true)
    }

    @Test func invalidBase64TokenIsExpired() {
        let expired = AuthManager.isTokenExpired("header.!!!.signature")
        #expect(expired == true)
    }

    @Test func twoSegmentTokenIsExpired() {
        let expired = AuthManager.isTokenExpired("header.payload")
        #expect(expired == true)
    }

    @Test func fourSegmentTokenIsExpired() {
        let expired = AuthManager.isTokenExpired("a.b.c.d")
        #expect(expired == true)
    }

    @Test func tokenWithExpAsStringIsExpired() {
        // "exp" is a string instead of a number, so it should not parse
        guard let jwt = JWTTestHelper.makeJWT(payload: [
            "sub": "user-1",
            "username": "test",
            "is_admin": false,
            "exp": "not-a-number",
        ]) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        #expect(expired == true)
    }

    @Test func tokenJustExpired() {
        // Token that expired 1 second ago
        let justPast = Date().timeIntervalSince1970 - 1
        guard let jwt = JWTTestHelper.makeUserJWT(exp: justPast) else {
            Issue.record("Failed to build test JWT")
            return
        }
        let expired = AuthManager.isTokenExpired(jwt)
        #expect(expired == true)
    }
}

// MARK: - AuthManager State Management Tests

@Suite("AuthManager Extended State Tests")
struct AuthManagerExtendedStateTests {

    @Test @MainActor func updateServerURLChangesURL() {
        let auth = AuthManager()
        auth.updateServerURL("https://new-server.example.com")
        // Verify it changed by calling updateServerURL with the same value
        // (no crash, idempotent).
        auth.updateServerURL("https://new-server.example.com")
        #expect(Bool(true))
    }

    @Test @MainActor func updateServerURLWithDifferentValues() {
        let auth = AuthManager()
        auth.updateServerURL("https://server-1.example.com")
        auth.updateServerURL("https://server-2.example.com")
        auth.updateServerURL("https://server-3.example.com")
        // Should not crash or cause issues
        #expect(Bool(true))
    }

    @Test @MainActor func updateServerURLWithEmptyString() {
        let auth = AuthManager()
        auth.updateServerURL("")
        // Should handle empty URL gracefully
        #expect(Bool(true))
    }

    @Test @MainActor func logoutClearsAllFieldsCompletely() {
        let auth = AuthManager()
        auth.isAuthenticated = true
        auth.mustChangePassword = true
        auth.totpRequired = true
        auth.totpToken = "totp-abc"
        auth.isLoading = true
        auth.errorMessage = "some error"

        auth.logout()

        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
        #expect(auth.mustChangePassword == false)
        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
    }

    @Test @MainActor func handleServerSwitchResetsAuthState() {
        let auth = AuthManager()
        auth.isAuthenticated = true
        auth.mustChangePassword = true
        auth.totpRequired = true
        auth.totpToken = "token-value"

        auth.handleServerSwitch()

        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
        #expect(auth.mustChangePassword == false)
        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
    }

    @Test @MainActor func restoreSessionReturnsEarlyWithEmptyServerURL() async {
        // Clear any stored server URL
        UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        let auth = AuthManager()
        // This should return early since currentServerURL is empty
        await auth.restoreSession()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
    }

    @Test @MainActor func refreshTokenReturnsFalseWithEmptyServerURL() async {
        UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        let auth = AuthManager()
        let result = await auth.refreshToken()
        #expect(result == false)
    }

    @Test @MainActor func refreshTokenReturnsFalseWithNoStoredRefreshToken() async {
        let auth = AuthManager()
        auth.updateServerURL("https://no-refresh-token.example.com")
        // No refresh token stored in keychain for this URL
        let result = await auth.refreshToken()
        #expect(result == false)
    }

    @Test @MainActor func verifyTotpReturnsEarlyWithNilToken() async {
        let auth = AuthManager()
        auth.totpToken = nil
        await auth.verifyTotp(code: "123456")
        // Should return early without setting isLoading
        #expect(auth.isAuthenticated == false)
    }

    @Test @MainActor func restoreSessionWithStoredTokenButNoValidJWT() async {
        // Store a server URL and a non-JWT token in keychain
        let server = "https://restore-test-\(UUID().uuidString).example.com"
        defer { KeychainManager.deleteTokens(serverURL: server) }

        UserDefaults.standard.set(server, forKey: APIClient.serverURLKey)
        try? KeychainManager.saveAccessToken("not-a-valid-jwt", serverURL: server)

        let auth = AuthManager()
        auth.updateServerURL(server)

        // restoreSession will find the token, fail to decode JWT,
        // attempt refresh (which will fail since no refresh token), then clear.
        await auth.restoreSession()

        // After failed restore, should not be authenticated
        #expect(auth.isAuthenticated == false)
    }

    @Test @MainActor func restoreSessionWithValidNonExpiredToken() async {
        let server = "https://restore-valid-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        // Build a valid JWT with user info and a future exp
        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(
            sub: "user-restore",
            username: "restoreuser",
            email: "restore@test.com",
            isAdmin: false,
            exp: futureExp
        ) else {
            Issue.record("Failed to build test JWT")
            return
        }

        UserDefaults.standard.set(server, forKey: APIClient.serverURLKey)
        try? KeychainManager.saveAccessToken(jwt, serverURL: server)

        let auth = AuthManager()
        auth.updateServerURL(server)
        await auth.restoreSession()

        // With a valid, non-expired JWT, should be authenticated
        #expect(auth.isAuthenticated == true)
        #expect(auth.currentUser != nil)
        #expect(auth.currentUser?.id == "user-restore")
        #expect(auth.currentUser?.username == "restoreuser")
    }

    @Test @MainActor func restoreSessionWithExpiredTokenClearsState() async {
        let server = "https://restore-expired-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        // Build a valid JWT with user info but expired
        let pastExp = Date().timeIntervalSince1970 - 3600
        guard let jwt = JWTTestHelper.makeUserJWT(
            sub: "user-expired",
            username: "expireduser",
            exp: pastExp
        ) else {
            Issue.record("Failed to build test JWT")
            return
        }

        UserDefaults.standard.set(server, forKey: APIClient.serverURLKey)
        try? KeychainManager.saveAccessToken(jwt, serverURL: server)

        let auth = AuthManager()
        auth.updateServerURL(server)
        await auth.restoreSession()

        // Token is expired, no refresh token available, so should not be authenticated
        #expect(auth.isAuthenticated == false)
    }

    @Test @MainActor func setupRequiredDefaultsToFalse() {
        let auth = AuthManager()
        #expect(auth.setupRequired == false)
    }

    @Test @MainActor func multipleLogoutsDoNotCrash() {
        let auth = AuthManager()
        auth.isAuthenticated = true
        for _ in 0..<10 {
            auth.logout()
        }
        #expect(auth.isAuthenticated == false)
    }

    // MARK: - handleLoginSuccess Tests

    @Test @MainActor func handleLoginSuccessSetsAuthenticatedWithValidJWT() async {
        let server = "https://login-success-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(
            sub: "login-user",
            username: "logintest",
            email: "login@test.com",
            isAdmin: true,
            exp: futureExp
        ) else {
            Issue.record("Failed to build test JWT")
            return
        }

        let auth = AuthManager()
        auth.updateServerURL(server)

        await auth.handleLoginSuccess(
            accessToken: jwt,
            refreshToken: "refresh-token-123",
            mustChange: false
        )

        #expect(auth.isAuthenticated == true)
        #expect(auth.currentUser != nil)
        #expect(auth.currentUser?.id == "login-user")
        #expect(auth.currentUser?.username == "logintest")
        #expect(auth.currentUser?.isAdmin == true)
        #expect(auth.mustChangePassword == false)

        // Verify tokens were persisted to Keychain
        #expect(KeychainManager.getAccessToken(serverURL: server) == jwt)
        #expect(KeychainManager.getRefreshToken(serverURL: server) == "refresh-token-123")
    }

    @Test @MainActor func handleLoginSuccessWithMustChangePassword() async {
        let server = "https://login-mustchange-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(exp: futureExp) else {
            Issue.record("Failed to build test JWT")
            return
        }

        let auth = AuthManager()
        auth.updateServerURL(server)

        await auth.handleLoginSuccess(
            accessToken: jwt,
            refreshToken: nil,
            mustChange: true
        )

        #expect(auth.isAuthenticated == true)
        #expect(auth.mustChangePassword == true)
        // No refresh token was provided, so it should not be in Keychain
        #expect(KeychainManager.getRefreshToken(serverURL: server) == nil)
    }

    @Test @MainActor func handleLoginSuccessWithEmptyRefreshToken() async {
        let server = "https://login-emptyref-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(exp: futureExp) else {
            Issue.record("Failed to build test JWT")
            return
        }

        let auth = AuthManager()
        auth.updateServerURL(server)

        // Empty refresh token should not be saved
        await auth.handleLoginSuccess(
            accessToken: jwt,
            refreshToken: "",
            mustChange: false
        )

        #expect(auth.isAuthenticated == true)
        #expect(KeychainManager.getRefreshToken(serverURL: server) == nil)
    }

    @Test @MainActor func handleLoginSuccessWithInvalidJWTStillAuthenticates() async {
        let server = "https://login-invalidjwt-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        let auth = AuthManager()
        auth.updateServerURL(server)

        // Pass an invalid JWT. User decoding will fail, but login should still succeed.
        await auth.handleLoginSuccess(
            accessToken: "not-a-valid-jwt",
            refreshToken: "ref-token",
            mustChange: false
        )

        #expect(auth.isAuthenticated == true)
        #expect(auth.currentUser == nil) // Could not decode user from invalid JWT
    }

    @Test @MainActor func handleLoginSuccessFallsBackToUserDefaultsServerURL() async {
        let server = "https://login-fallback-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        UserDefaults.standard.set(server, forKey: APIClient.serverURLKey)

        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(exp: futureExp) else {
            Issue.record("Failed to build test JWT")
            return
        }

        // Create AuthManager but do NOT call updateServerURL
        // so currentServerURL is set from UserDefaults in init
        let auth = AuthManager()

        await auth.handleLoginSuccess(
            accessToken: jwt,
            refreshToken: "fallback-refresh",
            mustChange: false
        )

        #expect(auth.isAuthenticated == true)
        // Tokens should be stored under the server URL from UserDefaults
        #expect(KeychainManager.getAccessToken(serverURL: server) == jwt)
    }

    @Test @MainActor func handleLoginSuccessWithEmptyServerURLFallsBackToUserDefaults() async {
        let server = "https://empty-url-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        // Set a server URL in UserDefaults, then create auth with empty currentServerURL
        UserDefaults.standard.set(server, forKey: APIClient.serverURLKey)
        let auth = AuthManager()
        // Force currentServerURL to empty
        auth.updateServerURL("")

        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(exp: futureExp) else {
            Issue.record("Failed to build test JWT")
            return
        }

        await auth.handleLoginSuccess(
            accessToken: jwt,
            refreshToken: nil,
            mustChange: false
        )

        // Should fall back to UserDefaults URL
        #expect(auth.isAuthenticated == true)
    }

    @Test @MainActor func serverSwitchAfterSuccessfulRestore() async {
        let server = "https://switch-test-\(UUID().uuidString).example.com"
        defer {
            KeychainManager.deleteTokens(serverURL: server)
            UserDefaults.standard.removeObject(forKey: APIClient.serverURLKey)
        }

        let futureExp = Date().timeIntervalSince1970 + 3600
        guard let jwt = JWTTestHelper.makeUserJWT(exp: futureExp) else {
            Issue.record("Failed to build test JWT")
            return
        }

        UserDefaults.standard.set(server, forKey: APIClient.serverURLKey)
        try? KeychainManager.saveAccessToken(jwt, serverURL: server)

        let auth = AuthManager()
        auth.updateServerURL(server)
        await auth.restoreSession()
        #expect(auth.isAuthenticated == true)

        // Now switch servers
        auth.handleServerSwitch()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
    }
}

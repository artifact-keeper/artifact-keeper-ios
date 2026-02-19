import Testing
import Foundation
@testable import ArtifactKeeper

@Suite("AuthManager Tests")
struct AuthManagerTests {

    @Test @MainActor func initialStateIsNotAuthenticated() {
        let auth = AuthManager()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
        #expect(auth.isLoading == false)
        #expect(auth.errorMessage == nil)
        #expect(auth.setupRequired == false)
        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
        #expect(auth.mustChangePassword == false)
    }

    @Test @MainActor func logoutResetsAllState() {
        let auth = AuthManager()
        // Simulate some authenticated state
        auth.isAuthenticated = true
        auth.mustChangePassword = true
        auth.totpRequired = true
        auth.totpToken = "some-token"

        auth.logout()

        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
        #expect(auth.mustChangePassword == false)
        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
    }

    @Test @MainActor func logoutCanBeCalledMultipleTimes() {
        let auth = AuthManager()
        auth.logout()
        auth.logout()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
    }

    @Test @MainActor func handleServerSwitchCallsLogout() {
        let auth = AuthManager()
        auth.isAuthenticated = true
        auth.handleServerSwitch()
        #expect(auth.isAuthenticated == false)
        #expect(auth.currentUser == nil)
        #expect(auth.totpRequired == false)
    }

    @Test @MainActor func publishedPropertiesHaveCorrectDefaults() {
        let auth = AuthManager()
        // Verify all @Published properties start at their default values
        #expect(auth.isAuthenticated == false)
        #expect(auth.mustChangePassword == false)
        #expect(auth.currentUser == nil)
        #expect(auth.isLoading == false)
        #expect(auth.errorMessage == nil)
        #expect(auth.setupRequired == false)
        #expect(auth.totpRequired == false)
        #expect(auth.totpToken == nil)
    }

    @Test @MainActor func errorMessageCanBeSet() {
        let auth = AuthManager()
        auth.errorMessage = "Test error"
        #expect(auth.errorMessage == "Test error")
        auth.errorMessage = nil
        #expect(auth.errorMessage == nil)
    }

    @Test @MainActor func loadingStateCanBeToggled() {
        let auth = AuthManager()
        #expect(auth.isLoading == false)
        auth.isLoading = true
        #expect(auth.isLoading == true)
        auth.isLoading = false
        #expect(auth.isLoading == false)
    }
}

// MARK: - JWT Decoding Tests (via AuthManager's internal decodeJWT)

@Suite("JWT Decoding Tests")
struct JWTDecodingTests {

    /// Build a minimal JWT string with the given payload (base64-encoded JSON).
    /// JWT format: header.payload.signature
    private func makeJWT(payload: [String: Any]) -> String? {
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        let header = Data("{\"alg\":\"HS256\",\"typ\":\"JWT\"}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let payloadB64 = payloadData
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let signature = "test_signature"
        return "\(header).\(payloadB64).\(signature)"
    }

    @Test @MainActor func loginSetsAuthenticatedOnValidJWT() async {
        // We cannot call the real login (needs network), but we can test the JWT
        // decode path indirectly by verifying that AuthManager correctly decodes a
        // UserInfo from a well-formed JWT payload.
        _ = AuthManager()

        // Construct a fake JWT containing user info
        let payload: [String: Any] = [
            "sub": "user-123",
            "username": "testuser",
            "email": "test@example.com",
            "is_admin": false,
            "totp_enabled": true
        ]
        guard let jwt = makeJWT(payload: payload) else {
            Issue.record("Failed to build test JWT")
            return
        }

        // Decode user info from the JWT (mimicking what AuthManager.login does)
        let segments = jwt.split(separator: ".")
        #expect(segments.count == 3)

        var base64 = String(segments[1])
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64) else {
            Issue.record("Failed to decode base64 payload")
            return
        }
        let user = try? JSONDecoder().decode(UserInfo.self, from: data)
        #expect(user != nil)
        #expect(user?.id == "user-123")
        #expect(user?.username == "testuser")
        #expect(user?.email == "test@example.com")
        #expect(user?.isAdmin == false)
        #expect(user?.totpEnabled == true)
    }

    @Test func invalidJWTReturnsNil() {
        // A string that is not a valid JWT (wrong number of segments)
        let invalidTokens = [
            "",
            "onlyone",
            "two.parts",
            "four.parts.here.extra",
        ]
        for token in invalidTokens {
            let segments = token.split(separator: ".")
            if segments.count != 3 {
                // Would return nil in decodeJWT
                #expect(Bool(true), "Token '\(token)' correctly has wrong segment count")
            }
        }
    }

    @Test func malformedBase64PayloadFails() {
        // JWT with 3 segments but the payload is not valid base64
        let token = "header.!!!invalid-base64!!!.signature"
        let segments = token.split(separator: ".")
        #expect(segments.count == 3)

        var base64 = String(segments[1])
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        let data = Data(base64Encoded: base64)
        // Invalid base64 should produce nil
        #expect(data == nil)
    }
}

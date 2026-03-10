import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - KeychainManager Tests

@Suite("KeychainManager Tests")
struct KeychainManagerTests {

    /// Unique server URL scoped to each test run to avoid cross-test pollution.
    private func uniqueServerURL(_ suffix: String = "") -> String {
        "https://test-\(UUID().uuidString)\(suffix).example.com"
    }

    /// Clean up tokens for a given server URL after a test.
    private func cleanup(serverURL: String) {
        KeychainManager.deleteTokens(serverURL: serverURL)
    }

    // MARK: - Save and Retrieve Access Token

    @Test func saveAndRetrieveAccessToken() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveAccessToken("access-token-abc", serverURL: server)
        let retrieved = KeychainManager.getAccessToken(serverURL: server)
        #expect(retrieved == "access-token-abc")
    }

    @Test func saveAndRetrieveRefreshToken() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveRefreshToken("refresh-token-xyz", serverURL: server)
        let retrieved = KeychainManager.getRefreshToken(serverURL: server)
        #expect(retrieved == "refresh-token-xyz")
    }

    @Test func saveAccessTokenOverwritesPrevious() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveAccessToken("first-token", serverURL: server)
        try KeychainManager.saveAccessToken("second-token", serverURL: server)
        let retrieved = KeychainManager.getAccessToken(serverURL: server)
        #expect(retrieved == "second-token")
    }

    @Test func saveRefreshTokenOverwritesPrevious() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveRefreshToken("first-refresh", serverURL: server)
        try KeychainManager.saveRefreshToken("second-refresh", serverURL: server)
        let retrieved = KeychainManager.getRefreshToken(serverURL: server)
        #expect(retrieved == "second-refresh")
    }

    // MARK: - Retrieve Non-Existent Tokens

    @Test func getAccessTokenReturnsNilWhenNotStored() {
        let server = uniqueServerURL("-nonexistent")
        let retrieved = KeychainManager.getAccessToken(serverURL: server)
        #expect(retrieved == nil)
    }

    @Test func getRefreshTokenReturnsNilWhenNotStored() {
        let server = uniqueServerURL("-nonexistent")
        let retrieved = KeychainManager.getRefreshToken(serverURL: server)
        #expect(retrieved == nil)
    }

    // MARK: - Delete Tokens

    @Test func deleteTokensRemovesBoth() throws {
        let server = uniqueServerURL()

        try KeychainManager.saveAccessToken("access-to-delete", serverURL: server)
        try KeychainManager.saveRefreshToken("refresh-to-delete", serverURL: server)

        // Verify they exist first
        #expect(KeychainManager.getAccessToken(serverURL: server) != nil)
        #expect(KeychainManager.getRefreshToken(serverURL: server) != nil)

        KeychainManager.deleteTokens(serverURL: server)

        #expect(KeychainManager.getAccessToken(serverURL: server) == nil)
        #expect(KeychainManager.getRefreshToken(serverURL: server) == nil)
    }

    @Test func deleteTokensIsIdempotent() {
        let server = uniqueServerURL("-idempotent")
        // Deleting tokens that were never stored should not crash.
        KeychainManager.deleteTokens(serverURL: server)
        KeychainManager.deleteTokens(serverURL: server)
        #expect(KeychainManager.getAccessToken(serverURL: server) == nil)
    }

    @Test func deleteAccessTokenOnlyRemovesAccess() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveAccessToken("access-only", serverURL: server)
        try KeychainManager.saveRefreshToken("refresh-stays", serverURL: server)

        KeychainManager.deleteAccessToken(serverURL: server)

        #expect(KeychainManager.getAccessToken(serverURL: server) == nil)
        #expect(KeychainManager.getRefreshToken(serverURL: server) == "refresh-stays")
    }

    // MARK: - Server URL Scoping

    @Test func tokensScopedToDifferentServers() throws {
        let serverA = uniqueServerURL("-A")
        let serverB = uniqueServerURL("-B")
        defer {
            cleanup(serverURL: serverA)
            cleanup(serverURL: serverB)
        }

        try KeychainManager.saveAccessToken("token-A", serverURL: serverA)
        try KeychainManager.saveAccessToken("token-B", serverURL: serverB)

        #expect(KeychainManager.getAccessToken(serverURL: serverA) == "token-A")
        #expect(KeychainManager.getAccessToken(serverURL: serverB) == "token-B")

        // Deleting from A should not affect B
        KeychainManager.deleteTokens(serverURL: serverA)
        #expect(KeychainManager.getAccessToken(serverURL: serverA) == nil)
        #expect(KeychainManager.getAccessToken(serverURL: serverB) == "token-B")
    }

    @Test func refreshTokensScopedToDifferentServers() throws {
        let serverA = uniqueServerURL("-refA")
        let serverB = uniqueServerURL("-refB")
        defer {
            cleanup(serverURL: serverA)
            cleanup(serverURL: serverB)
        }

        try KeychainManager.saveRefreshToken("refresh-A", serverURL: serverA)
        try KeychainManager.saveRefreshToken("refresh-B", serverURL: serverB)

        #expect(KeychainManager.getRefreshToken(serverURL: serverA) == "refresh-A")
        #expect(KeychainManager.getRefreshToken(serverURL: serverB) == "refresh-B")
    }

    // MARK: - Edge Cases

    @Test func saveEmptyStringToken() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveAccessToken("", serverURL: server)
        let retrieved = KeychainManager.getAccessToken(serverURL: server)
        #expect(retrieved == "")
    }

    @Test func saveLongToken() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        // Simulate a realistic JWT length (around 800+ chars)
        let longToken = String(repeating: "a", count: 2048)
        try KeychainManager.saveAccessToken(longToken, serverURL: server)
        let retrieved = KeychainManager.getAccessToken(serverURL: server)
        #expect(retrieved == longToken)
    }

    @Test func saveTokenWithSpecialCharacters() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        let specialToken = "test-header.test-payload.signature+/special-chars=="
        try KeychainManager.saveAccessToken(specialToken, serverURL: server)
        let retrieved = KeychainManager.getAccessToken(serverURL: server)
        #expect(retrieved == specialToken)
    }

    @Test func serverURLWithPortNumber() throws {
        let server = "https://registry.test:8080"
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveAccessToken("port-token", serverURL: server)
        #expect(KeychainManager.getAccessToken(serverURL: server) == "port-token")
    }

    @Test func serverURLWithPath() throws {
        let server = "https://registry.test/api/v1"
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveAccessToken("path-token", serverURL: server)
        #expect(KeychainManager.getAccessToken(serverURL: server) == "path-token")
    }

    @Test func deleteAccessTokenWhenOnlyRefreshExists() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        try KeychainManager.saveRefreshToken("only-refresh", serverURL: server)
        // Should not crash even though no access token exists
        KeychainManager.deleteAccessToken(serverURL: server)
        #expect(KeychainManager.getRefreshToken(serverURL: server) == "only-refresh")
    }

    @Test func multipleOverwriteCycles() throws {
        let server = uniqueServerURL()
        defer { cleanup(serverURL: server) }

        for i in 1...5 {
            try KeychainManager.saveAccessToken("token-\(i)", serverURL: server)
            try KeychainManager.saveRefreshToken("refresh-\(i)", serverURL: server)
        }
        #expect(KeychainManager.getAccessToken(serverURL: server) == "token-5")
        #expect(KeychainManager.getRefreshToken(serverURL: server) == "refresh-5")
    }
}

// MARK: - KeychainError Tests

@Suite("KeychainError Tests")
struct KeychainErrorTests {

    @Test func encodingFailedDescription() {
        let error = KeychainError.encodingFailed
        #expect(error.errorDescription == "Failed to encode token data")
    }

    @Test func unhandledErrorDescription() {
        let error = KeychainError.unhandledError(status: -25300)
        #expect(error.errorDescription == "Keychain error: -25300")
    }

    @Test func unhandledErrorWithZeroStatus() {
        let error = KeychainError.unhandledError(status: 0)
        #expect(error.errorDescription == "Keychain error: 0")
    }

    @Test func keychainErrorConformsToLocalizedError() {
        let error: any LocalizedError = KeychainError.encodingFailed
        #expect(error.errorDescription != nil)
    }

    @Test func keychainErrorConformsToSendable() {
        let error: any Sendable = KeychainError.encodingFailed
        _ = error
        #expect(Bool(true))
    }

    @Test func variousOSStatusValues() {
        let statuses: [OSStatus] = [-25300, -25299, -25308, -34018, 0, 1]
        for status in statuses {
            let error = KeychainError.unhandledError(status: status)
            #expect(error.errorDescription?.contains("\(status)") == true)
        }
    }
}

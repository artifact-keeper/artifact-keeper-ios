import Foundation
import Security

/// Stores and retrieves authentication tokens in the system Keychain.
///
/// Each Keychain item is scoped to the server URL so multiple server
/// connections do not collide.
struct KeychainManager: Sendable {

    /// The account names used as secondary keys within the Keychain.
    private enum Account: String {
        case accessToken = "com.artifactkeeper.accessToken"
        case refreshToken = "com.artifactkeeper.refreshToken"
    }

    // MARK: - Public API

    /// Save the access token for a given server URL.
    static func saveAccessToken(_ token: String, serverURL: String) throws {
        try save(token, account: .accessToken, service: serviceName(for: serverURL))
    }

    /// Save the refresh token for a given server URL.
    static func saveRefreshToken(_ token: String, serverURL: String) throws {
        try save(token, account: .refreshToken, service: serviceName(for: serverURL))
    }

    /// Retrieve the stored access token for a given server URL.
    static func getAccessToken(serverURL: String) -> String? {
        return retrieve(account: .accessToken, service: serviceName(for: serverURL))
    }

    /// Retrieve the stored refresh token for a given server URL.
    static func getRefreshToken(serverURL: String) -> String? {
        return retrieve(account: .refreshToken, service: serviceName(for: serverURL))
    }

    /// Delete both tokens for a given server URL.
    static func deleteTokens(serverURL: String) {
        let service = serviceName(for: serverURL)
        delete(account: .accessToken, service: service)
        delete(account: .refreshToken, service: service)
    }

    /// Delete the access token only (e.g. after it expires).
    static func deleteAccessToken(serverURL: String) {
        delete(account: .accessToken, service: serviceName(for: serverURL))
    }

    // MARK: - Keychain Operations

    private static func serviceName(for serverURL: String) -> String {
        "com.artifactkeeper.auth.\(serverURL)"
    }

    private static func save(_ value: String, account: Account, service: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Try to update an existing item first.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet, add it.
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
            return
        }

        throw KeychainError.unhandledError(status: updateStatus)
    }

    private static func retrieve(account: Account, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private static func delete(account: Account, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError, Sendable {
    case encodingFailed
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode token data"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}

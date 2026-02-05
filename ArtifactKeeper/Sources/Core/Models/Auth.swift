import Foundation

struct LoginRequest: Codable, Sendable {
    let username: String
    let password: String
}

struct LoginResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let mustChangePassword: Bool?
    let totpRequired: Bool?
    let totpToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case mustChangePassword = "must_change_password"
        case totpRequired = "totp_required"
        case totpToken = "totp_token"
    }
}

struct UserInfo: Codable, Sendable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let isAdmin: Bool
    let totpEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id = "sub"
        case username
        case email
        case isAdmin = "is_admin"
        case totpEnabled = "totp_enabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        totpEnabled = try container.decodeIfPresent(Bool.self, forKey: .totpEnabled) ?? false
    }
}

struct SetupStatusResponse: Codable, Sendable {
    let setupRequired: Bool

    enum CodingKeys: String, CodingKey {
        case setupRequired = "setup_required"
    }
}

struct TotpSetupResponse: Codable, Sendable {
    let secret: String
    let qrCodeUrl: String

    enum CodingKeys: String, CodingKey {
        case secret
        case qrCodeUrl = "qr_code_url"
    }
}

struct TotpEnableResponse: Codable, Sendable {
    let backupCodes: [String]

    enum CodingKeys: String, CodingKey {
        case backupCodes = "backup_codes"
    }
}

struct TotpCodeRequest: Encodable, Sendable {
    let code: String
}

struct TotpVerifyRequest: Encodable, Sendable {
    let totpToken: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case totpToken = "totp_token"
        case code
    }
}

struct TotpDisableRequest: Encodable, Sendable {
    let password: String
    let code: String
}

struct ChangePasswordRequest: Encodable, Sendable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

// MARK: - Profile

struct ProfileResponse: Codable, Sendable {
    let id: String
    let username: String
    let email: String
    let displayName: String?
    let isAdmin: Bool
    let totpEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case totpEnabled = "totp_enabled"
    }
}

struct UpdateProfileRequest: Encodable, Sendable {
    let displayName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
    }
}

// MARK: - API Keys

struct ApiKey: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let keyPrefix: String
    let createdAt: String
    let expiresAt: String?
    let lastUsedAt: String?
    let scopes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, scopes
        case keyPrefix = "key_prefix"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
    }
}

struct ApiKeysListResponse: Codable, Sendable {
    let apiKeys: [ApiKey]

    enum CodingKeys: String, CodingKey {
        case apiKeys = "api_keys"
    }
}

struct CreateApiKeyRequest: Encodable, Sendable {
    let name: String
    let expiresInDays: Int?
    let scopes: [String]?

    enum CodingKeys: String, CodingKey {
        case name, scopes
        case expiresInDays = "expires_in_days"
    }
}

struct CreateApiKeyResponse: Codable, Sendable {
    let apiKey: ApiKey
    let key: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case key
    }
}

// MARK: - Access Tokens

struct AccessToken: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let tokenPrefix: String
    let createdAt: String
    let expiresAt: String?
    let lastUsedAt: String?
    let scopes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, scopes
        case tokenPrefix = "token_prefix"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
    }
}

struct AccessTokensListResponse: Codable, Sendable {
    let accessTokens: [AccessToken]

    enum CodingKeys: String, CodingKey {
        case accessTokens = "access_tokens"
    }
}

struct CreateAccessTokenRequest: Encodable, Sendable {
    let name: String
    let expiresInDays: Int?
    let scopes: [String]?

    enum CodingKeys: String, CodingKey {
        case name, scopes
        case expiresInDays = "expires_in_days"
    }
}

struct CreateAccessTokenResponse: Codable, Sendable {
    let accessToken: AccessToken
    let token: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case token
    }
}

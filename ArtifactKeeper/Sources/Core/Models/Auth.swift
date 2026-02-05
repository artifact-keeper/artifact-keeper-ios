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

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case mustChangePassword = "must_change_password"
    }
}

struct UserInfo: Codable, Sendable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id = "sub"
        case username
        case email
        case isAdmin = "is_admin"
    }
}

struct SetupStatusResponse: Codable, Sendable {
    let setupRequired: Bool

    enum CodingKeys: String, CodingKey {
        case setupRequired = "setup_required"
    }
}

import Foundation

struct LoginRequest: Codable, Sendable {
    let username: String
    let password: String
}

struct LoginResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let user: UserInfo
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct UserInfo: Codable, Sendable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let isAdmin: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, username, email
        case isAdmin = "is_admin"
    }
}

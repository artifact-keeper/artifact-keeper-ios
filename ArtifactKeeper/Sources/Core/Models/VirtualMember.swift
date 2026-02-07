import Foundation

struct VirtualMember: Codable, Identifiable, Sendable {
    let id: String
    let memberRepoId: String
    let memberRepoKey: String
    let memberRepoName: String
    let memberRepoType: String
    let priority: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case memberRepoId = "member_repo_id"
        case memberRepoKey = "member_repo_key"
        case memberRepoName = "member_repo_name"
        case memberRepoType = "member_repo_type"
        case priority
        case createdAt = "created_at"
    }
}

struct VirtualMembersResponse: Codable, Sendable {
    let items: [VirtualMember]
}

struct AddMemberRequest: Codable, Sendable {
    let memberKey: String
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case memberKey = "member_key"
        case priority
    }
}

struct MemberPriority: Codable, Sendable {
    let memberKey: String
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case memberKey = "member_key"
        case priority
    }
}

struct ReorderMembersRequest: Codable, Sendable {
    let members: [MemberPriority]
}

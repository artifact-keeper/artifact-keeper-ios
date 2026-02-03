import Foundation

struct Peer: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let url: String
    let status: String
    let lastSyncAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, url, status
        case lastSyncAt = "last_sync_at"
        case createdAt = "created_at"
    }
}

struct PeerListResponse: Codable, Sendable {
    let items: [Peer]
    let total: Int
}

struct ReplicationRule: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let sourceRepoKey: String
    let targetPeerId: String
    let targetRepoKey: String
    let schedule: String?
    let enabled: Bool
    let lastRunAt: String?
    let lastRunStatus: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, schedule, enabled
        case sourceRepoKey = "source_repo_key"
        case targetPeerId = "target_peer_id"
        case targetRepoKey = "target_repo_key"
        case lastRunAt = "last_run_at"
        case lastRunStatus = "last_run_status"
        case createdAt = "created_at"
    }
}

struct ReplicationRuleListResponse: Codable, Sendable {
    let items: [ReplicationRule]
    let total: Int
}

struct Webhook: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let url: String
    let events: [String]
    let enabled: Bool
    let lastTriggeredAt: String?
    let lastStatus: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, url, events, enabled
        case lastTriggeredAt = "last_triggered_at"
        case lastStatus = "last_status"
        case createdAt = "created_at"
    }
}

struct WebhookListResponse: Codable, Sendable {
    let items: [Webhook]
    let total: Int
}

import Foundation

struct Peer: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let endpointUrl: String
    let status: String
    let region: String?
    let cacheSizeBytes: Int64
    let cacheUsedBytes: Int64
    let cacheUsagePercent: Double
    let lastHeartbeatAt: String?
    let lastSyncAt: String?
    let createdAt: String
    let apiKey: String
    let isLocal: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, status, region
        case endpointUrl = "endpoint_url"
        case cacheSizeBytes = "cache_size_bytes"
        case cacheUsedBytes = "cache_used_bytes"
        case cacheUsagePercent = "cache_usage_percent"
        case lastHeartbeatAt = "last_heartbeat_at"
        case lastSyncAt = "last_sync_at"
        case createdAt = "created_at"
        case apiKey = "api_key"
        case isLocal = "is_local"
    }
}

struct PeerListResponse: Codable, Sendable {
    let items: [Peer]
    let total: Int
}

struct PeerConnection: Codable, Identifiable, Sendable {
    let id: String
    let targetPeerId: String
    let status: String
    let latencyMs: Int?
    let bandwidthEstimateBps: Int64?
    let sharedArtifactsCount: Int
    let sharedChunksCount: Int
    let bytesTransferredTotal: Int64
    let transferSuccessCount: Int
    let transferFailureCount: Int
    let lastProbedAt: String?
    let lastTransferAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case targetPeerId = "target_peer_id"
        case latencyMs = "latency_ms"
        case bandwidthEstimateBps = "bandwidth_estimate_bps"
        case sharedArtifactsCount = "shared_artifacts_count"
        case sharedChunksCount = "shared_chunks_count"
        case bytesTransferredTotal = "bytes_transferred_total"
        case transferSuccessCount = "transfer_success_count"
        case transferFailureCount = "transfer_failure_count"
        case lastProbedAt = "last_probed_at"
        case lastTransferAt = "last_transfer_at"
    }
}

struct Webhook: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let url: String
    let events: [String]
    let isEnabled: Bool
    let repositoryId: String?
    let lastTriggeredAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, url, events
        case isEnabled = "is_enabled"
        case repositoryId = "repository_id"
        case lastTriggeredAt = "last_triggered_at"
        case createdAt = "created_at"
    }
}

struct WebhookListResponse: Codable, Sendable {
    let items: [Webhook]
    let total: Int
}

struct TestWebhookResponse: Codable, Sendable {
    let success: Bool
    let statusCode: Int?
    let responseBody: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case statusCode = "status_code"
        case responseBody = "response_body"
        case error
    }
}

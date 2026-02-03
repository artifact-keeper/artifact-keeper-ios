import Foundation

// GET /api/v1/admin/stats
struct AdminStats: Codable, Sendable {
    let totalRepositories: Int
    let totalArtifacts: Int
    let totalStorageBytes: Int64
    let totalDownloads: Int
    let totalUsers: Int
    let activePeers: Int
    let pendingSyncTasks: Int

    enum CodingKeys: String, CodingKey {
        case totalRepositories = "total_repositories"
        case totalArtifacts = "total_artifacts"
        case totalStorageBytes = "total_storage_bytes"
        case totalDownloads = "total_downloads"
        case totalUsers = "total_users"
        case activePeers = "active_peers"
        case pendingSyncTasks = "pending_sync_tasks"
    }
}

// GET /api/v1/admin/analytics/storage/breakdown
struct StorageBreakdown: Codable, Identifiable, Sendable {
    let repositoryId: String
    let repositoryKey: String
    let repositoryName: String
    let format: String
    let artifactCount: Int
    let storageBytes: Int64
    let downloadCount: Int
    let lastUploadAt: String?

    var id: String { repositoryId }

    enum CodingKeys: String, CodingKey {
        case repositoryId = "repository_id"
        case repositoryKey = "repository_key"
        case repositoryName = "repository_name"
        case format
        case artifactCount = "artifact_count"
        case storageBytes = "storage_bytes"
        case downloadCount = "download_count"
        case lastUploadAt = "last_upload_at"
    }
}

// GET /api/v1/admin/analytics/downloads/trend?days=30
struct DownloadTrend: Codable, Identifiable, Sendable {
    let date: String
    let downloadCount: Int

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case downloadCount = "download_count"
    }
}

// GET /api/v1/admin/analytics/storage/growth?days=30
struct StorageGrowth: Codable, Sendable {
    let periodStart: String
    let periodEnd: String
    let storageBytesStart: Int64
    let storageBytesEnd: Int64
    let storageGrowthBytes: Int64
    let storageGrowthPercent: Double
    let artifactsStart: Int
    let artifactsEnd: Int
    let artifactsAdded: Int
    let downloadsInPeriod: Int

    enum CodingKeys: String, CodingKey {
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case storageBytesStart = "storage_bytes_start"
        case storageBytesEnd = "storage_bytes_end"
        case storageGrowthBytes = "storage_growth_bytes"
        case storageGrowthPercent = "storage_growth_percent"
        case artifactsStart = "artifacts_start"
        case artifactsEnd = "artifacts_end"
        case artifactsAdded = "artifacts_added"
        case downloadsInPeriod = "downloads_in_period"
    }
}

// GET /health
struct HealthResponse: Codable, Sendable {
    let status: String
    let version: String?
    let demoMode: Bool?
    let checks: [String: HealthCheck]?

    enum CodingKeys: String, CodingKey {
        case status, version, checks
        case demoMode = "demo_mode"
    }
}

struct HealthCheck: Codable, Sendable {
    let status: String
}

// GET /api/v1/admin/monitoring/health-log
struct HealthLogEntry: Codable, Identifiable, Sendable {
    let serviceName: String
    let status: String
    let previousStatus: String
    let message: String?
    let responseTimeMs: Int
    let checkedAt: String

    var id: String { "\(serviceName)-\(checkedAt)" }

    enum CodingKeys: String, CodingKey {
        case serviceName = "service_name"
        case status
        case previousStatus = "previous_status"
        case message
        case responseTimeMs = "response_time_ms"
        case checkedAt = "checked_at"
    }
}

// GET /api/v1/admin/monitoring/alerts
struct AlertState: Codable, Identifiable, Sendable {
    let serviceName: String
    let currentStatus: String
    let consecutiveFailures: Int
    let lastAlertSentAt: String?
    let suppressedUntil: String?
    let updatedAt: String

    var id: String { serviceName }

    enum CodingKeys: String, CodingKey {
        case serviceName = "service_name"
        case currentStatus = "current_status"
        case consecutiveFailures = "consecutive_failures"
        case lastAlertSentAt = "last_alert_sent_at"
        case suppressedUntil = "suppressed_until"
        case updatedAt = "updated_at"
    }
}

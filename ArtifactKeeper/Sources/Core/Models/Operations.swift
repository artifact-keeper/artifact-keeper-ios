import Foundation

struct AnalyticsOverview: Codable, Sendable {
    let totalDownloads: Int
    let totalUploads: Int
    let totalStorageBytes: Int64
    let activeRepositories: Int
    let topPackages: [TopPackage]

    enum CodingKeys: String, CodingKey {
        case totalDownloads = "total_downloads"
        case totalUploads = "total_uploads"
        case totalStorageBytes = "total_storage_bytes"
        case activeRepositories = "active_repositories"
        case topPackages = "top_packages"
    }
}

struct TopPackage: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let format: String
    let downloadCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, format
        case downloadCount = "download_count"
    }
}

struct SystemHealth: Codable, Sendable {
    let status: String
    let version: String?
    let uptime: String?
    let database: ServiceStatus?
    let storage: ServiceStatus?
}

struct ServiceStatus: Codable, Sendable {
    let status: String
    let message: String?
}

struct StorageInfo: Codable, Sendable {
    let totalBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64

    enum CodingKeys: String, CodingKey {
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case availableBytes = "available_bytes"
    }
}

struct TelemetryMetrics: Codable, Sendable {
    let requestsPerMinute: Double?
    let errorRate: Double?
    let avgLatencyMs: Double?
    let activeConnections: Int?

    enum CodingKeys: String, CodingKey {
        case requestsPerMinute = "requests_per_minute"
        case errorRate = "error_rate"
        case avgLatencyMs = "avg_latency_ms"
        case activeConnections = "active_connections"
    }
}

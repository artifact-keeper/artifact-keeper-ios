import Foundation

// MARK: - Migrations (1.2.1 /api/v1/migrations/*)

/// A migration job (GET /api/v1/migrations, GET /api/v1/migrations/{id}).
/// Lifecycle actions (start/pause/resume/cancel) return an updated job.
struct MigrationJob: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let sourceConnectionId: String
    let status: String
    let jobType: String
    let totalItems: Int
    let completedItems: Int
    let failedItems: Int
    let skippedItems: Int
    let totalBytes: Int64
    let transferredBytes: Int64
    let progressPercent: Double
    let errorSummary: String?
    let estimatedTimeRemaining: Int64?
    let startedAt: String?
    let finishedAt: String?
    let createdAt: String
}

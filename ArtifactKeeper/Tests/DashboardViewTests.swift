import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - DashboardHelpers Tests

@Suite("DashboardHelpers Tests")
struct DashboardHelpersTests {

    // MARK: - formatBytes

    @Test func formatBytesZero() {
        let result = DashboardHelpers.formatBytes(0)
        #expect(result.contains("0") || result.lowercased().contains("zero"))
    }

    @Test func formatBytesKilobytes() {
        let result = DashboardHelpers.formatBytes(1024)
        // ByteCountFormatter with .file style produces "1 KB" or locale variant
        #expect(result.contains("KB") || result.contains("kB"))
    }

    @Test func formatBytesMegabytes() {
        let result = DashboardHelpers.formatBytes(10 * 1024 * 1024)
        #expect(result.contains("MB"))
    }

    @Test func formatBytesGigabytes() {
        let result = DashboardHelpers.formatBytes(5 * 1024 * 1024 * 1024)
        #expect(result.contains("GB"))
    }

    @Test func formatBytesTerabytes() {
        let result = DashboardHelpers.formatBytes(2 * 1024 * 1024 * 1024 * 1024)
        #expect(result.contains("TB"))
    }

    @Test func formatBytesSmallValues() {
        // Values below 1 KB
        let result = DashboardHelpers.formatBytes(500)
        #expect(!result.isEmpty)
    }

    @Test func formatBytesNonPowerOfTwo() {
        let result = DashboardHelpers.formatBytes(123_456_789)
        #expect(result.contains("MB"))
    }

    // MARK: - iconForService

    @Test func iconForServiceDatabase() {
        #expect(DashboardHelpers.iconForService("database") == "cylinder.fill")
        #expect(DashboardHelpers.iconForService("postgres") == "cylinder.fill")
        #expect(DashboardHelpers.iconForService("postgresql") == "cylinder.fill")
    }

    @Test func iconForServiceDatabaseCaseInsensitive() {
        #expect(DashboardHelpers.iconForService("Database") == "cylinder.fill")
        #expect(DashboardHelpers.iconForService("POSTGRES") == "cylinder.fill")
        #expect(DashboardHelpers.iconForService("PostgreSQL") == "cylinder.fill")
    }

    @Test func iconForServiceStorage() {
        #expect(DashboardHelpers.iconForService("storage") == "externaldrive.fill")
        #expect(DashboardHelpers.iconForService("s3") == "externaldrive.fill")
        #expect(DashboardHelpers.iconForService("filesystem") == "externaldrive.fill")
    }

    @Test func iconForServiceScanner() {
        #expect(DashboardHelpers.iconForService("scanner") == "shield.fill")
        #expect(DashboardHelpers.iconForService("trivy") == "shield.fill")
    }

    @Test func iconForServiceSearch() {
        #expect(DashboardHelpers.iconForService("search") == "magnifyingglass")
        #expect(DashboardHelpers.iconForService("meilisearch") == "magnifyingglass")
    }

    @Test func iconForServiceUnknown() {
        #expect(DashboardHelpers.iconForService("redis") == "circle.fill")
        #expect(DashboardHelpers.iconForService("unknown") == "circle.fill")
        #expect(DashboardHelpers.iconForService("") == "circle.fill")
    }

    // MARK: - healthCategory

    @Test func healthCategoryHealthy() {
        #expect(DashboardHelpers.healthCategory(for: "healthy") == "healthy")
        #expect(DashboardHelpers.healthCategory(for: "ok") == "healthy")
        #expect(DashboardHelpers.healthCategory(for: "up") == "healthy")
    }

    @Test func healthCategoryHealthyCaseInsensitive() {
        #expect(DashboardHelpers.healthCategory(for: "Healthy") == "healthy")
        #expect(DashboardHelpers.healthCategory(for: "OK") == "healthy")
        #expect(DashboardHelpers.healthCategory(for: "UP") == "healthy")
    }

    @Test func healthCategoryDegraded() {
        #expect(DashboardHelpers.healthCategory(for: "degraded") == "degraded")
        #expect(DashboardHelpers.healthCategory(for: "warning") == "degraded")
    }

    @Test func healthCategoryUnhealthy() {
        #expect(DashboardHelpers.healthCategory(for: "down") == "unhealthy")
        #expect(DashboardHelpers.healthCategory(for: "error") == "unhealthy")
        #expect(DashboardHelpers.healthCategory(for: "unknown") == "unhealthy")
        #expect(DashboardHelpers.healthCategory(for: "") == "unhealthy")
    }
}

// MARK: - HealthResponse Model Tests (for Dashboard data)

@Suite("HealthResponse Tests")
struct HealthResponseTests {

    @Test func healthResponseDecodesMinimal() throws {
        let json = """
        {"status": "healthy"}
        """.data(using: .utf8)!
        let health = try JSONDecoder().decode(HealthResponse.self, from: json)
        #expect(health.status == "healthy")
        #expect(health.version == nil)
        #expect(health.checks == nil)
        #expect(health.demoMode == nil)
    }

    @Test func healthResponseDecodesWithVersion() throws {
        let json = """
        {"status": "healthy", "version": "1.2.0"}
        """.data(using: .utf8)!
        let health = try JSONDecoder().decode(HealthResponse.self, from: json)
        #expect(health.version == "1.2.0")
    }

    @Test func healthResponseDecodesWithChecks() throws {
        let json = """
        {
            "status": "healthy",
            "version": "1.0.0",
            "demo_mode": false,
            "checks": {
                "database": {"status": "healthy"},
                "storage": {"status": "healthy"},
                "search": {"status": "degraded"}
            }
        }
        """.data(using: .utf8)!
        let health = try JSONDecoder().decode(HealthResponse.self, from: json)
        #expect(health.checks?.count == 3)
        #expect(health.checks?["database"]?.status == "healthy")
        #expect(health.checks?["search"]?.status == "degraded")
        #expect(health.demoMode == false)
    }
}

// MARK: - AdminStats Model Tests

@Suite("AdminStats Tests")
struct AdminStatsTests {

    @Test func adminStatsDecodesFromSnakeCase() throws {
        let json = """
        {
            "total_repositories": 12,
            "total_artifacts": 345,
            "total_storage_bytes": 1073741824,
            "total_downloads": 9876,
            "total_users": 42,
            "active_peers": 3,
            "pending_sync_tasks": 0
        }
        """.data(using: .utf8)!
        let stats = try JSONDecoder().decode(AdminStats.self, from: json)
        #expect(stats.totalRepositories == 12)
        #expect(stats.totalArtifacts == 345)
        #expect(stats.totalStorageBytes == 1_073_741_824)
        #expect(stats.totalDownloads == 9876)
        #expect(stats.totalUsers == 42)
        #expect(stats.activePeers == 3)
        #expect(stats.pendingSyncTasks == 0)
    }
}

// MARK: - RepoSecurityScore Aggregation Tests

@Suite("Security Score Aggregation Tests")
struct SecurityScoreAggregationTests {

    private func makeScore(
        grade: String,
        critical: Int = 0,
        high: Int = 0,
        medium: Int = 0,
        low: Int = 0
    ) -> RepoSecurityScore {
        RepoSecurityScore(
            id: UUID().uuidString,
            repositoryId: UUID().uuidString,
            grade: grade,
            score: 100,
            criticalCount: critical,
            highCount: high,
            mediumCount: medium,
            lowCount: low
        )
    }

    @Test func aggregateCriticalCounts() {
        let scores = [
            makeScore(grade: "B", critical: 2),
            makeScore(grade: "C", critical: 5),
            makeScore(grade: "A", critical: 0),
        ]
        let total = scores.reduce(0) { $0 + $1.criticalCount }
        #expect(total == 7)
    }

    @Test func aggregateHighCounts() {
        let scores = [
            makeScore(grade: "B", high: 3),
            makeScore(grade: "C", high: 10),
        ]
        let total = scores.reduce(0) { $0 + $1.highCount }
        #expect(total == 13)
    }

    @Test func gradeACounting() {
        let scores = [
            makeScore(grade: "A"),
            makeScore(grade: "A"),
            makeScore(grade: "B"),
            makeScore(grade: "F"),
        ]
        let gradeA = scores.filter { $0.grade == "A" }.count
        #expect(gradeA == 2)
    }

    @Test func gradeFCounting() {
        let scores = [
            makeScore(grade: "A"),
            makeScore(grade: "F"),
            makeScore(grade: "F"),
        ]
        let gradeF = scores.filter { $0.grade == "F" }.count
        #expect(gradeF == 2)
    }

    @Test func emptyScoresAggregateToZero() {
        let scores: [RepoSecurityScore] = []
        let totalCritical = scores.reduce(0) { $0 + $1.criticalCount }
        let totalHigh = scores.reduce(0) { $0 + $1.highCount }
        #expect(totalCritical == 0)
        #expect(totalHigh == 0)
    }
}

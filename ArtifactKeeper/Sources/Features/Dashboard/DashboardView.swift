import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var health: HealthResponse?
    @State private var stats: AdminStats?
    @State private var repos: [Repository] = []
    @State private var scores: [RepoSecurityScore] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    private var isLoggedIn: Bool { authManager.isAuthenticated }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading...")
                        .padding(.top, 60)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    VStack(spacing: 24) {
                        healthSection
                        statsSection
                        securityOverviewSection
                        recentReposSection
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Dashboard")
            .accountToolbar()
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Health Section

    @ViewBuilder
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Health", systemImage: "heart.fill")
                .font(.headline)
                .padding(.horizontal)

            if let health {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    HealthCard(
                        name: "Overall",
                        status: health.status,
                        icon: "checkmark.shield.fill"
                    )

                    if let checks = health.checks {
                        ForEach(checks.sorted(by: { $0.key < $1.key }), id: \.key) { name, check in
                            HealthCard(
                                name: name.capitalized,
                                status: check.status,
                                icon: iconForService(name)
                            )
                        }
                    }
                }
                .padding(.horizontal)

                if let version = health.version {
                    HStack {
                        Text("Server version:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(version)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Health data unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overview", systemImage: "chart.bar.fill")
                .font(.headline)
                .padding(.horizontal)

            if let stats {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    StatCard(
                        title: "Repositories",
                        value: "\(stats.totalRepositories)",
                        icon: "folder.fill",
                        color: .blue
                    )
                    StatCard(
                        title: "Artifacts",
                        value: "\(stats.totalArtifacts)",
                        icon: "doc.fill",
                        color: .green
                    )
                    StatCard(
                        title: "Downloads",
                        value: "\(stats.totalDownloads)",
                        icon: "arrow.down.circle.fill",
                        color: .orange
                    )
                    StatCard(
                        title: "Storage",
                        value: formatBytes(stats.totalStorageBytes),
                        icon: "externaldrive.fill",
                        color: .purple
                    )
                    StatCard(
                        title: "Users",
                        value: "\(stats.totalUsers)",
                        icon: "person.2.fill",
                        color: .cyan
                    )
                    StatCard(
                        title: "Active Peers",
                        value: "\(stats.activePeers)",
                        icon: "network",
                        color: .mint
                    )
                }
                .padding(.horizontal)
            } else {
                // Fall back to repo-count-only stats when admin stats are unavailable
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    StatCard(
                        title: "Repositories",
                        value: "\(repos.count)",
                        icon: "folder.fill",
                        color: .blue
                    )
                    StatCard(
                        title: "Security Scores",
                        value: "\(scores.count)",
                        icon: "shield.checkered",
                        color: .green
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Security Overview

    @ViewBuilder
    private var securityOverviewSection: some View {
        if !scores.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Security Overview", systemImage: "shield.checkered")
                    .font(.headline)
                    .padding(.horizontal)

                let totalCritical = scores.reduce(0) { $0 + $1.criticalCount }
                let totalHigh = scores.reduce(0) { $0 + $1.highCount }
                let totalMedium = scores.reduce(0) { $0 + $1.mediumCount }
                let totalLow = scores.reduce(0) { $0 + $1.lowCount }
                let gradeA = scores.filter { $0.grade == "A" }.count
                let gradeF = scores.filter { $0.grade == "F" }.count

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    SeverityCard(label: "Critical", count: totalCritical, color: AppTheme.critical)
                    SeverityCard(label: "High", count: totalHigh, color: AppTheme.high)
                    SeverityCard(label: "Medium", count: totalMedium, color: AppTheme.medium)
                }
                .padding(.horizontal)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    SeverityCard(label: "Low", count: totalLow, color: AppTheme.low)
                    SeverityCard(label: "Grade A", count: gradeA, color: AppTheme.success)
                    SeverityCard(label: "Grade F", count: gradeF, color: AppTheme.error)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Repos

    @ViewBuilder
    private var recentReposSection: some View {
        if !repos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Repositories")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(repos.prefix(10)) { repo in
                    RepoRow(repo: repo)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = health == nil && repos.isEmpty
        errorMessage = nil

        // Health is always available (no auth required)
        do {
            health = try await apiClient.request("/health")
        } catch {
            // Health check failed, but do not block the entire view
        }

        // Admin stats require auth + admin role; load separately
        if isLoggedIn {
            do {
                stats = try await apiClient.request("/api/v1/admin/stats")
            } catch {
                stats = nil
            }
        }

        // Repos are available to everyone
        do {
            let repoResult: RepositoryListResponse = try await apiClient.request("/api/v1/repositories?per_page=100")
            repos = repoResult.items
        } catch {
            if health == nil {
                errorMessage = error.localizedDescription
            }
        }

        // Security scores require auth
        if isLoggedIn {
            do {
                let scoresResult: [RepoSecurityScore] = try await apiClient.request("/api/v1/security/scores")
                scores = scoresResult
            } catch {
                scores = []
            }
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        DashboardHelpers.formatBytes(bytes)
    }

    private func iconForService(_ name: String) -> String {
        DashboardHelpers.iconForService(name)
    }
}

// MARK: - Extracted Helpers (testable)

enum DashboardHelpers {
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func iconForService(_ name: String) -> String {
        switch name.lowercased() {
        case "database", "postgres", "postgresql": return "cylinder.fill"
        case "storage", "s3", "filesystem": return "externaldrive.fill"
        case "scanner", "trivy": return "shield.fill"
        case "search", "meilisearch": return "magnifyingglass"
        default: return "circle.fill"
        }
    }

    /// Map a health status string to a semantic category: "healthy", "degraded", or "unhealthy".
    static func healthCategory(for status: String) -> String {
        switch status.lowercased() {
        case "healthy", "ok", "up": return "healthy"
        case "degraded", "warning": return "degraded"
        default: return "unhealthy"
        }
    }
}

// MARK: - Health Card

struct HealthCard: View {
    let name: String
    let status: String
    let icon: String

    private var statusColor: Color {
        switch status.lowercased() {
        case "healthy", "ok", "up": return .green
        case "degraded", "warning": return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(status.capitalized)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Severity Card

struct SeverityCard: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Repo Row

struct RepoRow: View {
    let repo: Repository

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(repo.format.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)

                    Text(repo.repoType)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatBytes(repo.storageUsedBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}


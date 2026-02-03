import SwiftUI

struct AnalyticsView: View {
    @State private var stats: AdminStats?
    @State private var breakdown: [StorageBreakdown] = []
    @State private var growth: StorageGrowth?
    @State private var downloads: [DownloadTrend] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading analytics...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Analytics Unavailable",
                    systemImage: "chart.bar.xaxis",
                    description: Text(error)
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        if let stats = stats {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                            ], spacing: 16) {
                                AnalyticsCard(title: "Repositories", value: "\(stats.totalRepositories)", icon: "folder.fill", color: .blue)
                                AnalyticsCard(title: "Artifacts", value: "\(stats.totalArtifacts)", icon: "doc.fill", color: .green)
                                AnalyticsCard(title: "Downloads", value: "\(stats.totalDownloads)", icon: "arrow.down.circle.fill", color: .orange)
                                AnalyticsCard(title: "Storage", value: formatBytes(stats.totalStorageBytes), icon: "externaldrive.fill", color: .purple)
                                AnalyticsCard(title: "Users", value: "\(stats.totalUsers)", icon: "person.2.fill", color: .cyan)
                                AnalyticsCard(title: "Active Peers", value: "\(stats.activePeers)", icon: "network", color: .mint)
                            }
                            .padding(.horizontal)
                        }

                        if let growth = growth {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("30-Day Growth")
                                    .font(.headline)
                                    .padding(.horizontal)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                ], spacing: 12) {
                                    GrowthStat(label: "Storage Growth", value: formatBytes(growth.storageGrowthBytes))
                                    GrowthStat(label: "Growth %", value: String(format: "%.1f%%", growth.storageGrowthPercent))
                                    GrowthStat(label: "Artifacts Added", value: "\(growth.artifactsAdded)")
                                    GrowthStat(label: "Downloads", value: "\(growth.downloadsInPeriod)")
                                }
                                .padding(.horizontal)
                            }
                        }

                        if !downloads.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Downloads")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(downloads) { trend in
                                    HStack {
                                        Text(trend.date)
                                            .font(.caption.monospaced())
                                        Spacer()
                                        Text("\(trend.downloadCount) downloads")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        if !breakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Storage by Repository")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(breakdown.prefix(10)) { repo in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(repo.repositoryKey)
                                                .font(.body.weight(.medium))
                                            Text("\(repo.format.uppercased()) \u{2022} \(repo.artifactCount) artifacts")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(formatBytes(repo.storageBytes))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .refreshable { await loadAnalytics() }
        .task { await loadAnalytics() }
    }

    private func loadAnalytics() async {
        isLoading = stats == nil
        var gotData = false

        do {
            stats = try await apiClient.request("/api/v1/admin/stats")
            gotData = true
        } catch {}

        do {
            growth = try await apiClient.request("/api/v1/admin/analytics/storage/growth?days=30")
            gotData = true
        } catch {}

        do {
            downloads = try await apiClient.request("/api/v1/admin/analytics/downloads/trend?days=30")
            gotData = true
        } catch {}

        do {
            breakdown = try await apiClient.request("/api/v1/admin/analytics/storage/breakdown")
            gotData = true
        } catch {}

        if !gotData {
            errorMessage = "Could not load analytics. You may need admin privileges."
        } else {
            errorMessage = nil
        }
        isLoading = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct AnalyticsCard: View {
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

struct GrowthStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

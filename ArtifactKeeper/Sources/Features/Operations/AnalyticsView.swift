import SwiftUI

struct AnalyticsView: View {
    @State private var overview: AnalyticsOverview?
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
            } else if let overview = overview {
                ScrollView {
                    VStack(spacing: 20) {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 16) {
                            AnalyticsCard(title: "Downloads", value: "\(overview.totalDownloads)", icon: "arrow.down.circle.fill", color: .blue)
                            AnalyticsCard(title: "Uploads", value: "\(overview.totalUploads)", icon: "arrow.up.circle.fill", color: .green)
                            AnalyticsCard(title: "Storage", value: formatBytes(overview.totalStorageBytes), icon: "externaldrive.fill", color: .orange)
                            AnalyticsCard(title: "Active Repos", value: "\(overview.activeRepositories)", icon: "folder.fill", color: .purple)
                        }
                        .padding(.horizontal)

                        if !overview.topPackages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Top Packages")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(overview.topPackages) { pkg in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pkg.name)
                                                .font(.body.weight(.medium))
                                            Text(pkg.format.uppercased())
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Label("\(pkg.downloadCount)", systemImage: "arrow.down.circle")
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
        isLoading = overview == nil
        do {
            overview = try await apiClient.request("/api/v1/analytics/overview")
            errorMessage = nil
        } catch {
            if overview == nil {
                errorMessage = "Could not load analytics. This feature may not be available on your server."
            }
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

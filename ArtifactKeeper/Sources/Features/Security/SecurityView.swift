import SwiftUI

struct SecurityView: View {
    @State private var scores: [RepoSecurityScore] = []
    @State private var repoNames: [String: String] = [:]
    @State private var isLoading = true

    private let apiClient = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading security data...")
                } else if scores.isEmpty {
                    ContentUnavailableView(
                        "No Security Data",
                        systemImage: "shield.slash",
                        description: Text("Enable scanning on repositories to see security scores")
                    )
                } else {
                    List(scores) { score in
                        NavigationLink(value: score) {
                            SecurityScoreRow(
                                score: score,
                                repoName: repoNames[score.repositoryId]
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Security")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .navigationDestination(for: RepoSecurityScore.self) { score in
                ScanResultsView(
                    repositoryId: score.repositoryId,
                    repositoryName: repoNames[score.repositoryId] ?? score.repositoryId
                )
            }
        }
    }

    private func loadData() async {
        isLoading = scores.isEmpty
        do {
            async let scoresResult: [RepoSecurityScore] = apiClient.request("/api/v1/security/scores")
            async let reposResult: RepositoryListResponse = apiClient.request("/api/v1/repositories?per_page=200")

            let (s, r) = try await (scoresResult, reposResult)
            scores = s
            repoNames = Dictionary(uniqueKeysWithValues: r.items.map { ($0.id, $0.name) })
        } catch {
            // silent
        }
        isLoading = false
    }
}

// MARK: - Security Score Row

struct SecurityScoreRow: View {
    let score: RepoSecurityScore
    let repoName: String?

    var body: some View {
        HStack(spacing: 12) {
            GradeBadge(grade: score.grade)

            VStack(alignment: .leading, spacing: 4) {
                Text(repoName ?? score.repositoryId)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    if score.criticalCount > 0 {
                        SeverityPill(count: score.criticalCount, label: "C", color: .red)
                    }
                    if score.highCount > 0 {
                        SeverityPill(count: score.highCount, label: "H", color: .orange)
                    }
                    if score.mediumCount > 0 {
                        SeverityPill(count: score.mediumCount, label: "M", color: .yellow)
                    }
                    if score.lowCount > 0 {
                        SeverityPill(count: score.lowCount, label: "L", color: .blue)
                    }
                    if score.criticalCount + score.highCount + score.mediumCount + score.lowCount == 0 {
                        Text("Clean")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            Text("Score: \(score.score)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scan Results View

struct ScanResultsView: View {
    let repositoryId: String
    let repositoryName: String

    @State private var scans: [ScanResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading scan results...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if scans.isEmpty {
                ContentUnavailableView(
                    "No Scans",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No scans have been run for this repository")
                )
            } else {
                List(scans) { scan in
                    ScanResultRow(scan: scan)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(repositoryName)
        .refreshable {
            await loadScans()
        }
        .task {
            await loadScans()
        }
    }

    private func loadScans() async {
        isLoading = scans.isEmpty
        do {
            let response: ScanListResponse = try await apiClient.request(
                "/api/v1/security/scans?repository_id=\(repositoryId)"
            )
            scans = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Scan Result Row

struct ScanResultRow: View {
    let scan: ScanResult
    @State private var isExpanded = false

    var statusColor: Color {
        switch scan.status {
        case "completed": return .green
        case "running", "pending": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: scanTypeIcon)
                    .foregroundStyle(.blue)

                Text(scan.scanType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.body.weight(.medium))

                Spacer()

                Text(scan.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            // Findings breakdown
            HStack(spacing: 8) {
                if scan.criticalCount > 0 {
                    SeverityPill(count: scan.criticalCount, label: "C", color: .red)
                }
                if scan.highCount > 0 {
                    SeverityPill(count: scan.highCount, label: "H", color: .orange)
                }
                if scan.mediumCount > 0 {
                    SeverityPill(count: scan.mediumCount, label: "M", color: .yellow)
                }
                if scan.lowCount > 0 {
                    SeverityPill(count: scan.lowCount, label: "L", color: .blue)
                }

                Spacer()

                Text("\(scan.findingsCount) findings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Timestamps
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let started = scan.startedAt {
                        LabeledContent("Started", value: formatScanDate(started))
                            .font(.caption)
                    }
                    if let completed = scan.completedAt {
                        LabeledContent("Completed", value: formatScanDate(completed))
                            .font(.caption)
                    }
                    if let error = scan.errorMessage {
                        HStack(alignment: .top) {
                            Text("Error:")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var scanTypeIcon: String {
        switch scan.scanType {
        case "vulnerability": return "ladybug"
        case "license": return "doc.text"
        case "malware": return "ant"
        case "openscap": return "lock.shield"
        default: return "magnifyingglass"
        }
    }

    private func formatScanDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        return isoString
    }
}

// MARK: - Shared Components

struct GradeBadge: View {
    let grade: String

    var color: Color {
        switch grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        case "F": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(grade)
            .font(.title2.bold())
            .frame(width: 44, height: 44)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(color)
    }
}

struct SeverityPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        Text("\(count)\(label)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

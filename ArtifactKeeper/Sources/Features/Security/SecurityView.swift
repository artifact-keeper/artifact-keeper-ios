import SwiftUI

struct SecurityDashboardContentView: View {
    @State private var scores: [RepoSecurityScore] = []
    @State private var repoNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var dtStatus: DtStatus?
    @State private var dtPortfolioMetrics: DtPortfolioMetrics?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading security data...")
            } else if scores.isEmpty && dtStatus?.enabled != true {
                ContentUnavailableView(
                    "No Security Data",
                    systemImage: "shield.slash",
                    description: Text("Enable scanning on repositories to see security scores")
                )
            } else {
                List {
                    if let status = dtStatus, status.enabled {
                        Section {
                            DtPortfolioSummaryView(
                                status: status,
                                metrics: dtPortfolioMetrics
                            )
                        }
                    }

                    if !scores.isEmpty {
                        Section("Repository Scores") {
                            ForEach(scores) { score in
                                NavigationLink(value: score) {
                                    SecurityScoreRow(
                                        score: score,
                                        repoName: repoNames[score.repositoryId]
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
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

    private func loadData() async {
        isLoading = scores.isEmpty && dtStatus == nil
        do {
            async let scoresResult: [RepoSecurityScore] = apiClient.request("/api/v1/security/scores")
            async let reposResult: RepositoryListResponse = apiClient.request("/api/v1/repositories?per_page=200")

            let (s, r) = try await (scoresResult, reposResult)
            scores = s
            repoNames = Dictionary(uniqueKeysWithValues: r.items.map { ($0.id, $0.name) })
        } catch {
            // silent
        }

        // Load DT status independently — failures should not affect the rest
        do {
            let status: DtStatus = try await apiClient.request("/api/v1/dependency-track/status")
            dtStatus = status
            if status.enabled && status.healthy {
                let metrics: DtPortfolioMetrics = try await apiClient.request(
                    "/api/v1/dependency-track/metrics/portfolio"
                )
                dtPortfolioMetrics = metrics
            }
        } catch {
            // DT not available — that is fine, hide the section
        }

        isLoading = false
    }
}

// MARK: - Dependency-Track Portfolio Summary

struct DtPortfolioSummaryView: View {
    let status: DtStatus
    let metrics: DtPortfolioMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with status badge
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.title3)
                    .foregroundStyle(.indigo)

                Text("Dependency-Track")
                    .font(.headline)

                Spacer()

                Text(status.healthy ? "Connected" : "Disconnected")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (status.healthy ? Color.green : Color.red).opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(status.healthy ? .green : .red)
            }

            if let m = metrics {
                // Severity metrics grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    DtMetricBox(label: "Critical", value: m.critical, color: .red)
                    DtMetricBox(label: "High", value: m.high, color: .orange)
                    DtMetricBox(label: "Findings", value: m.findingsTotal, color: .secondary)
                    DtMetricBox(label: "Violations", value: m.policyViolationsTotal, color: .purple)
                    DtMetricBox(label: "Projects", value: m.projects, color: .blue)
                }

                // Audit progress
                let total = m.findingsTotal
                let audited = m.findingsAudited
                if total > 0 {
                    let percent = Int(Double(audited) / Double(total) * 100)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(audited) of \(total) findings audited (\(percent)%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !status.healthy {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Unable to reach Dependency-Track server")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DtMetricBox: View {
    let label: String
    let value: Int64
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(value > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(value > 0 ? 0.05 : 0.02), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct SecurityScansContentView: View {
    @State private var scans: [ScanResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isTriggering = false
    @State private var scanMessage: (success: Bool, text: String)?

    private let apiClient = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading scans...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Scans Unavailable",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(error)
                    )
                } else {
                    VStack(spacing: 0) {
                        if scans.isEmpty {
                            Spacer()
                            ContentUnavailableView(
                                "No Scans",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text("No scans have been run yet.")
                            )
                            Spacer()
                        } else {
                            List(scans) { scan in
                                NavigationLink(destination: ScanFindingsView(scan: scan)) {
                                    ScanResultRow(scan: scan)
                                }
                            }
                            .listStyle(.plain)
                        }

                        Divider()
                        VStack(spacing: 8) {
                            if let msg = scanMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: msg.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(msg.success ? .green : .red)
                                        .font(.caption)
                                    Text(msg.text)
                                        .font(.caption)
                                        .foregroundStyle(msg.success ? .green : .red)
                                }
                                .transition(.opacity)
                            }

                            Button {
                                Task { await triggerScan() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isTriggering {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Label(
                                        isTriggering ? "Scanning..." : "Trigger Scan",
                                        systemImage: "magnifyingglass"
                                    )
                                    .font(.body.weight(.medium))
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTriggering)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .refreshable { await loadScans() }
            .task { await loadScans() }
        }
    }

    private func loadScans() async {
        isLoading = scans.isEmpty
        do {
            let response: ScanListResponse = try await apiClient.request("/api/v1/security/scans?per_page=100")
            scans = response.items
            errorMessage = nil
        } catch {
            if scans.isEmpty {
                errorMessage = "Could not load scans. You may need to be authenticated."
            }
        }
        isLoading = false
    }

    private func triggerScan() async {
        isTriggering = true
        scanMessage = nil
        do {
            let body: [String: String?] = [:]  // empty body — scan all
            let response: TriggerScanResponse = try await apiClient.request(
                "/api/v1/security/scan",
                method: "POST",
                body: body
            )
            withAnimation {
                scanMessage = (success: true, text: response.message)
            }
            // Refresh the scan list after a short delay
            try? await Task.sleep(for: .seconds(2))
            await loadScans()
            try? await Task.sleep(for: .seconds(3))
            withAnimation { scanMessage = nil }
        } catch {
            withAnimation {
                scanMessage = (success: false, text: "Failed to trigger scan: \(error.localizedDescription)")
            }
            try? await Task.sleep(for: .seconds(5))
            withAnimation { scanMessage = nil }
        }
        isTriggering = false
    }
}

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
            .accountToolbar()
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
                    NavigationLink(destination: ScanFindingsView(scan: scan)) {
                        ScanResultRow(scan: scan)
                    }
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
            if let completed = scan.completedAt {
                Text(formatScanDate(completed))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .padding(.vertical, 4)
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

// MARK: - Scan Findings View

struct ScanFindingsView: View {
    let scan: ScanResult

    @State private var findings: [ScanFinding] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading findings...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if findings.isEmpty {
                ContentUnavailableView(
                    "No Findings",
                    systemImage: "checkmark.shield",
                    description: Text("This scan did not produce any findings.")
                )
            } else {
                List {
                    Section {
                        scanSummaryHeader
                    }

                    Section("Findings (\(findings.count))") {
                        ForEach(findings) { finding in
                            FindingRow(finding: finding)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(scan.scanType.replacingOccurrences(of: "_", with: " ").capitalized)
        .refreshable {
            await loadFindings()
        }
        .task {
            await loadFindings()
        }
    }

    private var scanSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = scan.artifactName {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.headline)
                    if let version = scan.artifactVersion {
                        Text("v\(version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                if scan.criticalCount > 0 {
                    SeverityPill(count: scan.criticalCount, label: "Critical", color: .red)
                }
                if scan.highCount > 0 {
                    SeverityPill(count: scan.highCount, label: "High", color: .orange)
                }
                if scan.mediumCount > 0 {
                    SeverityPill(count: scan.mediumCount, label: "Medium", color: .yellow)
                }
                if scan.lowCount > 0 {
                    SeverityPill(count: scan.lowCount, label: "Low", color: .blue)
                }
            }

            Text("\(scan.findingsCount) total findings")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadFindings() async {
        isLoading = findings.isEmpty
        do {
            let response: ScanFindingListResponse = try await apiClient.request(
                "/api/v1/security/scans/\(scan.id)/findings?per_page=200"
            )
            findings = response.items
            errorMessage = nil
        } catch {
            if findings.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

// MARK: - Finding Row

struct FindingRow: View {
    let finding: ScanFinding

    private var severityColor: Color {
        switch finding.severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Severity badge + title
            HStack(alignment: .top, spacing: 8) {
                Text(finding.severity.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(severityColor)

                Text(finding.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }

            // CVE ID as tappable link
            if let cveId = finding.cveId, !cveId.isEmpty {
                Link(cveId, destination: URL(string: "https://nvd.nist.gov/vuln/detail/\(cveId)")!)
                    .font(.caption.weight(.medium))
            }

            // Affected component and versions
            if let component = finding.affectedComponent, !component.isEmpty {
                HStack(spacing: 4) {
                    Text(component)
                        .font(.caption)
                        .foregroundStyle(.primary)

                    if let affected = finding.affectedVersion, !affected.isEmpty {
                        Text(affected)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }

                    if let fixed = finding.fixedVersion, !fixed.isEmpty {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(fixed)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }

            // Description
            if let description = finding.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Acknowledged badge
            if finding.isAcknowledged {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Acknowledged")
                        .font(.caption2.weight(.medium))
                    if let reason = finding.acknowledgedReason, !reason.isEmpty {
                        Text("— \(reason)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

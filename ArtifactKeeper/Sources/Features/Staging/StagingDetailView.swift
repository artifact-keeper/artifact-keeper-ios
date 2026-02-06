import SwiftUI

struct StagingDetailView: View {
    let repo: StagingRepository

    @State private var artifacts: [StagingArtifact] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedArtifacts: Set<StagingArtifact> = []
    @State private var isSelectionMode = false
    @State private var showingPromotionSheet = false
    @State private var showingHistorySheet = false
    @State private var artifactToPromote: StagingArtifact?
    @State private var expandedArtifactId: String?
    @State private var filterStatus: PolicyStatus?

    private let apiClient = APIClient.shared

    var filteredArtifacts: [StagingArtifact] {
        var result = artifacts

        if let status = filterStatus {
            result = result.filter { $0.policyStatus.lowercased() == status.rawValue }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText) ||
                ($0.version?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var passingArtifacts: [StagingArtifact] {
        selectedArtifacts.filter { $0.policyStatus.lowercased() == "passing" }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading artifacts...")
            } else if let error = errorMessage, artifacts.isEmpty {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if artifacts.isEmpty {
                ContentUnavailableView(
                    "No Artifacts",
                    systemImage: "tray",
                    description: Text("No artifacts are staged in this repository.")
                )
            } else {
                VStack(spacing: 0) {
                    // Filter bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All",
                                count: artifacts.count,
                                isSelected: filterStatus == nil,
                                color: .blue
                            ) {
                                filterStatus = nil
                            }

                            FilterChip(
                                title: "Passing",
                                count: artifacts.filter { $0.policyStatus.lowercased() == "passing" }.count,
                                isSelected: filterStatus == .passing,
                                color: .green
                            ) {
                                filterStatus = filterStatus == .passing ? nil : .passing
                            }

                            FilterChip(
                                title: "Failing",
                                count: artifacts.filter { $0.policyStatus.lowercased() == "failing" }.count,
                                isSelected: filterStatus == .failing,
                                color: .red
                            ) {
                                filterStatus = filterStatus == .failing ? nil : .failing
                            }

                            FilterChip(
                                title: "Pending",
                                count: artifacts.filter { $0.policyStatus.lowercased() == "pending" }.count,
                                isSelected: filterStatus == .pending,
                                color: .gray
                            ) {
                                filterStatus = filterStatus == .pending ? nil : .pending
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    Divider()

                    if filteredArtifacts.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        List(selection: isSelectionMode ? $selectedArtifacts : nil) {
                            ForEach(filteredArtifacts) { artifact in
                                StagingArtifactRow(
                                    artifact: artifact,
                                    isExpanded: expandedArtifactId == artifact.id,
                                    onToggleExpand: {
                                        withAnimation {
                                            if expandedArtifactId == artifact.id {
                                                expandedArtifactId = nil
                                            } else {
                                                expandedArtifactId = artifact.id
                                            }
                                        }
                                    }
                                )
                                .tag(artifact)
                                .swipeActions(edge: .trailing) {
                                    if artifact.policyStatus.lowercased() == "passing" {
                                        Button {
                                            artifactToPromote = artifact
                                        } label: {
                                            Label("Promote", systemImage: "arrow.up.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        if expandedArtifactId == artifact.id {
                                            expandedArtifactId = nil
                                        } else {
                                            expandedArtifactId = artifact.id
                                        }
                                    } label: {
                                        Label("Details", systemImage: "info.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                        .listStyle(.plain)
                        #if os(iOS)
                        .environment(\.editMode, .constant(isSelectionMode ? .active : .inactive))
                        #endif
                    }

                    // Bottom action bar for bulk promotion
                    if isSelectionMode && !selectedArtifacts.isEmpty {
                        Divider()
                        HStack {
                            Text("\(selectedArtifacts.count) selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if !passingArtifacts.isEmpty {
                                Button {
                                    showingPromotionSheet = true
                                } label: {
                                    Label("Promote \(passingArtifacts.count)", systemImage: "arrow.up.circle.fill")
                                        .font(.body.weight(.medium))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                Text("No passing artifacts selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(repo.name)
        .searchable(text: $searchText, prompt: "Search artifacts")
        .refreshable {
            await loadArtifacts()
        }
        .task {
            await loadArtifacts()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingHistorySheet = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }

                Button {
                    withAnimation {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedArtifacts.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
            }
        }
        .sheet(item: $artifactToPromote) { artifact in
            PromotionSheet(
                repo: repo,
                artifacts: [artifact],
                onComplete: {
                    await loadArtifacts()
                }
            )
        }
        .sheet(isPresented: $showingPromotionSheet) {
            PromotionSheet(
                repo: repo,
                artifacts: Array(passingArtifacts),
                onComplete: {
                    selectedArtifacts.removeAll()
                    isSelectionMode = false
                    await loadArtifacts()
                }
            )
        }
        .sheet(isPresented: $showingHistorySheet) {
            NavigationStack {
                PromotionHistoryView(repoKey: repo.key)
                    .navigationTitle("Promotion History")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingHistorySheet = false
                            }
                        }
                    }
            }
        }
    }

    private func loadArtifacts() async {
        isLoading = artifacts.isEmpty
        do {
            artifacts = try await apiClient.listStagingArtifacts(repoKey: repo.key)
            errorMessage = nil
        } catch {
            if artifacts.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text("(\(count))")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Staging Artifact Row

struct StagingArtifactRow: View {
    let artifact: StagingArtifact
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    private var policyStatusValue: PolicyStatus {
        PolicyStatus(rawValue: artifact.policyStatus.lowercased()) ?? .pending
    }

    private var statusColor: Color {
        switch policyStatusValue {
        case .passing: return .green
        case .failing: return .red
        case .warning: return .yellow
        case .pending: return .gray
        }
    }

    private var statusIcon: String {
        switch policyStatusValue {
        case .passing: return "checkmark.circle.fill"
        case .failing: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(artifact.name)
                        .font(.body.weight(.medium))

                    HStack(spacing: 8) {
                        if let version = artifact.version {
                            Text(version)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: Capsule())
                        }
                        Text(formatBytes(artifact.sizeBytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // CVE summary badge
                if let cve = artifact.cveSummary, cve.total > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        if cve.critical > 0 {
                            SeverityPill(count: cve.critical, label: "C", color: .red)
                        } else if cve.high > 0 {
                            SeverityPill(count: cve.high, label: "H", color: .orange)
                        } else if cve.medium > 0 {
                            SeverityPill(count: cve.medium, label: "M", color: .yellow)
                        }
                    }
                }

                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    // CVE breakdown
                    if let cve = artifact.cveSummary, cve.total > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vulnerabilities")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                if cve.critical > 0 {
                                    SeverityPill(count: cve.critical, label: "Critical", color: .red)
                                }
                                if cve.high > 0 {
                                    SeverityPill(count: cve.high, label: "High", color: .orange)
                                }
                                if cve.medium > 0 {
                                    SeverityPill(count: cve.medium, label: "Medium", color: .yellow)
                                }
                                if cve.low > 0 {
                                    SeverityPill(count: cve.low, label: "Low", color: .blue)
                                }
                            }

                            if cve.unpatched > 0 {
                                Text("\(cve.unpatched) unpatched")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    // License breakdown
                    if let license = artifact.licenseSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Licenses")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                if license.approved > 0 {
                                    LicenseBadge(count: license.approved, label: "Approved", color: .green)
                                }
                                if license.rejected > 0 {
                                    LicenseBadge(count: license.rejected, label: "Rejected", color: .red)
                                }
                                if license.unknown > 0 {
                                    LicenseBadge(count: license.unknown, label: "Unknown", color: .gray)
                                }
                            }

                            if let licenses = license.licenses, !licenses.isEmpty {
                                Text(licenses.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }

                    // Policy violations
                    if let violations = artifact.violations, !violations.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Policy Violations")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(violations) { violation in
                                PolicyViolationRow(violation: violation)
                            }
                        }
                    }

                    // Artifact path
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Path")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(artifact.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.leading, 44) // Align with content after status icon
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleExpand()
        }
    }
}

// MARK: - License Badge

struct LicenseBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption2.weight(.bold))
            Text(label)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

// MARK: - Policy Violation Row

struct PolicyViolationRow: View {
    let violation: PolicyViolation

    private var severityColor: Color {
        switch violation.severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(violation.severity.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(severityColor)

                Text(violation.policyName)
                    .font(.caption.weight(.medium))
            }

            Text(violation.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let details = violation.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

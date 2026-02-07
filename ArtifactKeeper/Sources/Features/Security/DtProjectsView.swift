import SwiftUI
import Charts

// MARK: - Projects List

struct DtProjectsListView: View {
    @State private var projects: [DtProject] = []
    @State private var projectMetrics: [String: DtProjectMetrics] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private let apiClient = APIClient.shared

    private var filteredProjects: [DtProject] {
        if searchText.isEmpty { return projects }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.version?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading DT projects...")
            } else if let error = errorMessage, projects.isEmpty {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder.badge.questionmark",
                    description: Text("No projects found in Dependency-Track")
                )
            } else {
                List(filteredProjects) { project in
                    NavigationLink(value: project) {
                        DtProjectRow(
                            project: project,
                            metrics: projectMetrics[project.uuid]
                        )
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search projects")
            }
        }
        .navigationDestination(for: DtProject.self) { project in
            DtProjectDetailView(project: project)
        }
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = projects.isEmpty
        do {
            let loadedProjects: [DtProject] = try await apiClient.request(
                "/api/v1/dependency-track/projects"
            )
            projects = loadedProjects

            // Fetch metrics for each project in parallel (cap at 30)
            var metricsMap: [String: DtProjectMetrics] = [:]
            await withTaskGroup(of: (String, DtProjectMetrics?)?.self) { group in
                for project in loadedProjects.prefix(30) {
                    group.addTask {
                        do {
                            let m: DtProjectMetrics = try await self.apiClient.request(
                                "/api/v1/dependency-track/projects/\(project.uuid)/metrics"
                            )
                            return (project.uuid, m)
                        } catch {
                            return nil
                        }
                    }
                }
                for await result in group {
                    if let (uuid, metrics) = result, let metrics {
                        metricsMap[uuid] = metrics
                    }
                }
            }
            projectMetrics = metricsMap
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Project Row

private struct DtProjectRow: View {
    let project: DtProject
    let metrics: DtProjectMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.name)
                    .font(.body.weight(.medium))

                if let version = project.version, !version.isEmpty {
                    Text(version)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }

                Spacer()

                if let m = metrics {
                    Text(String(format: "%.0f", m.inheritedRiskScore))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(riskColor(m.inheritedRiskScore))
                }
            }

            if let m = metrics {
                HStack(spacing: 6) {
                    if m.critical > 0 {
                        SeverityPill(count: Int(m.critical), label: "C", color: .red)
                    }
                    if m.high > 0 {
                        SeverityPill(count: Int(m.high), label: "H", color: .orange)
                    }
                    if m.medium > 0 {
                        SeverityPill(count: Int(m.medium), label: "M", color: .yellow)
                    }
                    if m.low > 0 {
                        SeverityPill(count: Int(m.low), label: "L", color: .blue)
                    }
                    if m.critical + m.high + m.medium + m.low == 0 {
                        Text("Clean")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Text("\(m.findingsAudited)/\(m.findingsTotal) audited")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let bomDate = project.lastBomImport {
                Text("Last BOM: \(formatEpoch(bomDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func riskColor(_ score: Double) -> Color {
        if score >= 70 { return .red }
        if score >= 40 { return .orange }
        if score >= 10 { return .yellow }
        return .green
    }

    private func formatEpoch(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Project Detail

struct DtProjectDetailView: View {
    let project: DtProject

    @State private var selectedTab = "findings"
    @State private var metrics: DtProjectMetrics?
    @State private var findings: [DtFinding] = []
    @State private var components: [DtComponentFull] = []
    @State private var violations: [DtPolicyViolation] = []
    @State private var metricsHistory: [DtProjectMetrics] = []
    @State private var isLoading = true
    @State private var triageFinding: DtFinding?

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            // Project header
            if let m = metrics {
                DtProjectHeaderView(project: project, metrics: m)
                    .padding()
            }

            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(["findings", "components", "violations", "metrics"], id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.capitalized)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            // Tab content
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else {
                    switch selectedTab {
                    case "findings":
                        DtFindingsListView(findings: findings, onTriageTap: { finding in
                            triageFinding = finding
                        })
                    case "components":
                        DtComponentsListView(components: components)
                    case "violations":
                        DtViolationsListView(violations: violations)
                    case "metrics":
                        DtProjectMetricsView(metrics: metrics, history: metricsHistory)
                    default:
                        EmptyView()
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle(project.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
        .sheet(item: $triageFinding) { finding in
            DtTriageSheet(projectUuid: project.uuid, finding: finding) {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = findings.isEmpty && metrics == nil
        do {
            async let metricsTask: DtProjectMetrics = apiClient.request(
                "/api/v1/dependency-track/projects/\(project.uuid)/metrics"
            )
            async let findingsTask: [DtFinding] = apiClient.request(
                "/api/v1/dependency-track/projects/\(project.uuid)/findings"
            )
            async let componentsTask: [DtComponentFull] = apiClient.request(
                "/api/v1/dependency-track/projects/\(project.uuid)/components"
            )
            async let violationsTask: [DtPolicyViolation] = apiClient.request(
                "/api/v1/dependency-track/projects/\(project.uuid)/violations"
            )
            async let historyTask: [DtProjectMetrics] = apiClient.request(
                "/api/v1/dependency-track/projects/\(project.uuid)/metrics/history?days=30"
            )

            let (m, f, c, v, h) = try await (metricsTask, findingsTask, componentsTask, violationsTask, historyTask)
            metrics = m
            findings = f
            components = c
            violations = v
            metricsHistory = h
        } catch {
            // partial loads are fine
        }
        isLoading = false
    }
}

// MARK: - Project Header

private struct DtProjectHeaderView: View {
    let project: DtProject
    let metrics: DtProjectMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let version = project.version, !version.isEmpty {
                    Text("v\(version)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text("Risk: \(String(format: "%.0f", metrics.inheritedRiskScore))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(riskColor(metrics.inheritedRiskScore))
            }

            HStack(spacing: 8) {
                severityBox("Critical", metrics.critical, .red)
                severityBox("High", metrics.high, .orange)
                severityBox("Medium", metrics.medium, .yellow)
                severityBox("Low", metrics.low, .blue)
            }

            HStack(spacing: 16) {
                Label("\(metrics.findingsAudited)/\(metrics.findingsTotal) audited", systemImage: "checkmark.seal")
                Label("\(metrics.policyViolationsTotal) violations", systemImage: "exclamationmark.shield")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func severityBox(_ label: String, _ count: Int64, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(count > 0 ? 0.05 : 0.02), in: RoundedRectangle(cornerRadius: 6))
    }

    private func riskColor(_ score: Double) -> Color {
        if score >= 70 { return .red }
        if score >= 40 { return .orange }
        if score >= 10 { return .yellow }
        return .green
    }
}

// MARK: - Findings List

private struct DtFindingsListView: View {
    let findings: [DtFinding]
    var onTriageTap: ((DtFinding) -> Void)?

    var body: some View {
        if findings.isEmpty {
            ContentUnavailableView(
                "No Findings",
                systemImage: "checkmark.shield",
                description: Text("No vulnerability findings for this project")
            )
        } else {
            List(findings) { finding in
                DtFindingRow(finding: finding)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTriageTap?(finding)
                    }
            }
            .listStyle(.plain)
        }
    }
}

private struct DtFindingRow: View {
    let finding: DtFinding

    private var severityColor: Color {
        switch finding.vulnerability.severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(finding.vulnerability.severity.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(severityColor)

                VStack(alignment: .leading, spacing: 2) {
                    // Vuln ID as link
                    if finding.vulnerability.source == "NVD" {
                        Link(finding.vulnerability.vulnId, destination: URL(string: "https://nvd.nist.gov/vuln/detail/\(finding.vulnerability.vulnId)")!)
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text(finding.vulnerability.vulnId)
                            .font(.subheadline.weight(.semibold))
                    }

                    if let title = finding.vulnerability.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if let cvss = finding.vulnerability.cvssV3BaseScore {
                    Text(String(format: "%.1f", cvss))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cvssColor(cvss))
                }
            }

            // Component
            HStack(spacing: 4) {
                Image(systemName: "shippingbox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(finding.component.group.map { "\($0)/" } ?? "")\(finding.component.name)")
                    .font(.caption)
                if let version = finding.component.version {
                    Text("@\(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Analysis state
            if let analysis = finding.analysis, let state = analysis.state, state != "NOT_SET" {
                Text(state.replacingOccurrences(of: "_", with: " "))
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(analysisColor(state).opacity(0.1), in: Capsule())
                    .foregroundStyle(analysisColor(state))
            }

            // CWE
            if let cwe = finding.vulnerability.cwe {
                Text("CWE-\(cwe.cweId): \(cwe.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func cvssColor(_ score: Double) -> Color {
        if score >= 9.0 { return .red }
        if score >= 7.0 { return .orange }
        if score >= 4.0 { return .yellow }
        return .blue
    }

    private func analysisColor(_ state: String) -> Color {
        switch state {
        case "RESOLVED", "FALSE_POSITIVE", "NOT_AFFECTED": return .green
        case "EXPLOITABLE": return .red
        case "IN_TRIAGE": return .orange
        default: return .secondary
        }
    }
}

// MARK: - Components List

private struct DtComponentsListView: View {
    let components: [DtComponentFull]

    var body: some View {
        if components.isEmpty {
            ContentUnavailableView(
                "No Components",
                systemImage: "shippingbox",
                description: Text("No components found for this project")
            )
        } else {
            List(components) { component in
                DtComponentRow(component: component)
            }
            .listStyle(.plain)
        }
    }
}

private struct DtComponentRow: View {
    let component: DtComponentFull

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(component.group.map { "\($0)/" } ?? "")\(component.name)")
                    .font(.body.weight(.medium))

                if let version = component.version {
                    Text(version)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }

                Spacer()

                if component.isInternal == true {
                    Text("Internal")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }

            HStack(spacing: 12) {
                if let license = component.resolvedLicense {
                    Label(license.name, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let purl = component.purl, !purl.isEmpty {
                    Text(purl)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Violations List

private struct DtViolationsListView: View {
    let violations: [DtPolicyViolation]

    var body: some View {
        if violations.isEmpty {
            ContentUnavailableView(
                "No Violations",
                systemImage: "checkmark.shield",
                description: Text("No policy violations for this project")
            )
        } else {
            List(violations) { violation in
                DtViolationRow(violation: violation)
            }
            .listStyle(.plain)
        }
    }
}

private struct DtViolationRow: View {
    let violation: DtPolicyViolation

    private var typeColor: Color {
        switch violation.policyCondition.policy.violationState.lowercased() {
        case "fail": return .red
        case "warn": return .orange
        case "info": return .blue
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(violation.policyCondition.policy.violationState.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(typeColor)

                Text(violation.policyCondition.policy.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(violation.type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "shippingbox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(violation.component.group.map { "\($0)/" } ?? "")\(violation.component.name)")
                    .font(.caption)
                if let version = violation.component.version {
                    Text("@\(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Condition: \(violation.policyCondition.subject) \(violation.policyCondition.operator) \(violation.policyCondition.value)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Metrics View

private struct DtProjectMetricsView: View {
    let metrics: DtProjectMetrics?
    let history: [DtProjectMetrics]

    private var chartData: [AggregatedMetricsPoint] {
        history.compactMap { point in
            guard let epoch = point.lastOccurrence else { return nil }
            let date = Date(timeIntervalSince1970: TimeInterval(epoch) / 1000)
            return AggregatedMetricsPoint(
                date: date,
                critical: point.critical,
                high: point.high,
                medium: point.medium,
                low: point.low
            )
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let m = metrics {
                    DtSeverityDistributionView(metrics: DtPortfolioMetrics(
                        critical: m.critical, high: m.high, medium: m.medium, low: m.low,
                        unassigned: m.unassigned, vulnerabilities: m.vulnerabilities,
                        findingsTotal: m.findingsTotal, findingsAudited: m.findingsAudited,
                        findingsUnaudited: m.findingsUnaudited, suppressions: m.suppressions,
                        inheritedRiskScore: m.inheritedRiskScore,
                        policyViolationsFail: m.policyViolationsFail,
                        policyViolationsWarn: m.policyViolationsWarn,
                        policyViolationsInfo: m.policyViolationsInfo,
                        policyViolationsTotal: m.policyViolationsTotal,
                        projects: 1
                    ))

                    DtRiskScoreGaugeView(riskScore: m.inheritedRiskScore)
                }

                if chartData.count > 1 {
                    DtPortfolioTrendChartView(history: chartData)
                }
            }
            .padding()
        }
    }
}

// MARK: - Triage Sheet

private struct DtTriageSheet: View {
    let projectUuid: String
    let finding: DtFinding
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedState: String
    @State private var justification = ""
    @State private var details = ""
    @State private var suppressed: Bool
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    private static let analysisStates = [
        "NOT_SET", "IN_TRIAGE", "EXPLOITABLE",
        "NOT_AFFECTED", "RESOLVED", "FALSE_POSITIVE"
    ]

    init(projectUuid: String, finding: DtFinding, onComplete: @escaping () async -> Void) {
        self.projectUuid = projectUuid
        self.finding = finding
        self.onComplete = onComplete
        _selectedState = State(initialValue: finding.analysis?.state ?? "NOT_SET")
        _suppressed = State(initialValue: finding.analysis?.isSuppressed ?? false)
    }

    var body: some View {
        NavigationStack {
            triageFormContent
        }
        .presentationDetents([.medium, .large])
    }

    private var triageFormContent: some View {
        let form = Form {
            findingHeaderSection
            analysisStateSection
            detailsSection
            suppressSection
            errorSection
        }
        .navigationTitle("Triage Finding")
        .toolbar { triageToolbarContent }
        .overlay { updatingOverlay }

        #if os(iOS)
        return form.navigationBarTitleDisplayMode(.inline)
        #else
        return form
        #endif
    }

    @ToolbarContentBuilder
    private var triageToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Update") {
                Task { await updateAnalysis() }
            }
            .disabled(isUpdating)
        }
    }

    @ViewBuilder
    private var updatingOverlay: some View {
        if isUpdating {
            ProgressView("Updating...")
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var findingHeaderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(finding.vulnerability.severity.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(severityColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(severityColor)

                    Text(finding.vulnerability.vulnId)
                        .font(.headline)
                }

                if let title = finding.vulnerability.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let componentPath = (finding.component.group.map { "\($0)/" } ?? "") + finding.component.name
                Text(componentPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var analysisStateSection: some View {
        Section("Analysis State") {
            ForEach(Self.analysisStates, id: \.self) { (state: String) in
                Button {
                    selectedState = state
                } label: {
                    stateRow(for: state)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func stateRow(for state: String) -> some View {
        HStack {
            Circle()
                .fill(stateColor(state))
                .frame(width: 10, height: 10)

            Text(state.replacingOccurrences(of: "_", with: " "))
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            if selectedState == state {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .font(.body.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Justification (optional)", text: $justification, axis: .vertical)
                .lineLimit(2...4)

            TextField("Additional details (optional)", text: $details, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    @ViewBuilder
    private var suppressSection: some View {
        Section {
            Toggle("Suppress Finding", isOn: $suppressed)
        } footer: {
            Text("Suppressed findings are hidden from default views and not counted in metrics.")
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Section {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var severityColor: Color {
        switch finding.vulnerability.severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .gray
        }
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "RESOLVED", "FALSE_POSITIVE", "NOT_AFFECTED": return .green
        case "EXPLOITABLE": return .red
        case "IN_TRIAGE": return .orange
        default: return .secondary
        }
    }

    private func updateAnalysis() async {
        isUpdating = true
        errorMessage = nil
        do {
            let request = UpdateDtAnalysisRequest(
                projectUuid: projectUuid,
                componentUuid: finding.component.uuid,
                vulnerabilityUuid: finding.vulnerability.uuid,
                state: selectedState,
                justification: justification.isEmpty ? nil : justification,
                details: details.isEmpty ? nil : details,
                suppressed: suppressed
            )
            let _: DtAnalysisResponse = try await apiClient.request(
                "/api/v1/dependency-track/analysis",
                method: "PUT",
                body: request
            )
            await onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }
}

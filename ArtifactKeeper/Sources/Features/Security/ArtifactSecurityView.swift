import SwiftUI

// Artifact-scoped security screens backed by the v1.2.1 ArtifactKeeperClient SDK.
//
// These cover the per-artifact half of the Security section that the repository-scoped
// views in SecurityView.swift do not:
//   - ArtifactScanResultsView: scans for one artifact, rescan  (list_artifact_scans,
//                                                                trigger_scan)
//   - ArtifactScanDetailView:  scan findings, acknowledge      (list_findings,
//                                                                acknowledge_finding,
//                                                                revoke_acknowledgment)
//   - ArtifactSbomView:        SBOM summary + components        (get_sbom_by_artifact,
//                                                                get_sbom_components)
//
// They reuse the shared row/badge components (ScanResultRow, SeverityPill, FindingRow,
// GradeBadge) defined in SecurityView.swift and the SDK-backed APIClient methods.

// MARK: - Artifact Security Hub

/// Entry point for an artifact's security surfaces. Offers navigation into the SBOM
/// and the scan results for the artifact.
struct ArtifactSecurityHub: View {
    let artifactId: String
    let artifactName: String

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ArtifactScanResultsView(artifactId: artifactId, artifactName: artifactName)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Results")
                            Text("Vulnerabilities and findings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "ladybug")
                            .foregroundStyle(.red)
                    }
                }

                NavigationLink {
                    ArtifactSbomView(artifactId: artifactId, artifactName: artifactName)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Software Bill of Materials")
                            Text("Components and licenses")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(.blue)
                    }
                }
            } header: {
                Text("Security")
            }
        }
    }
}

// MARK: - Artifact Scan Results

/// Lists the security scans for a single artifact.
struct ArtifactScanResultsView: View {
    let artifactId: String
    let artifactName: String

    @State private var scans: [ScanResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isScanning = false
    @State private var banner: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading scans...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await loadScans() } }
                }
            } else if scans.isEmpty {
                ContentUnavailableView {
                    Label("No Scans", systemImage: "checkmark.shield")
                } description: {
                    Text("This artifact has not been scanned yet.")
                } actions: {
                    Button {
                        Task { await triggerScan() }
                    } label: {
                        Label("Scan Now", systemImage: "ladybug")
                    }
                    .disabled(isScanning)
                }
            } else {
                List {
                    if let banner {
                        Section {
                            Label(banner, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    Section {
                        ForEach(scans) { scan in
                            NavigationLink(destination: ArtifactScanDetailView(scan: scan)) {
                                ScanResultRow(scan: scan)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Scans")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await triggerScan() }
                } label: {
                    if isScanning {
                        ProgressView()
                    } else {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isScanning)
            }
        }
        .refreshable { await loadScans() }
        .task { await loadScans() }
    }

    private func loadScans() async {
        isLoading = scans.isEmpty
        do {
            scans = try await apiClient.listArtifactScans(artifactId: artifactId)
            errorMessage = nil
        } catch {
            if scans.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func triggerScan() async {
        isScanning = true
        defer { isScanning = false }
        do {
            let result = try await apiClient.triggerScan(artifactId: artifactId)
            banner = result.message
            await loadScans()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Artifact Scan Detail

/// Shows a scan's severity breakdown and its findings.
struct ArtifactScanDetailView: View {
    let scan: ScanResult

    @State private var findings: [ScanFinding] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionError: String?
    @State private var acknowledgingFinding: ScanFinding?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading findings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await loadFindings() } }
                }
            } else {
                List {
                    Section { summaryHeader }

                    if findings.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No Findings",
                                systemImage: "checkmark.shield",
                                description: Text("This scan did not produce any findings.")
                            )
                        }
                    } else {
                        Section("Findings (\(findings.count))") {
                            ForEach(findings) { finding in
                                FindingRow(finding: finding)
                                    .swipeActions(edge: .trailing) {
                                        if finding.isAcknowledged {
                                            Button {
                                                Task { await revoke(finding) }
                                            } label: {
                                                Label("Revoke", systemImage: "arrow.uturn.backward")
                                            }
                                            .tint(.orange)
                                        } else {
                                            Button {
                                                acknowledgingFinding = finding
                                            } label: {
                                                Label("Acknowledge", systemImage: "checkmark.circle")
                                            }
                                            .tint(.green)
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(scanTypeTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await loadFindings() }
        .task { await loadFindings() }
        .sheet(item: $acknowledgingFinding) { finding in
            AcknowledgeFindingSheet(finding: finding) { reason in
                await acknowledge(finding, reason: reason)
            }
        }
        .alert("Action Failed", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private var scanTypeTitle: String {
        scan.scanType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let name = scan.artifactName {
                    Text(name)
                        .font(.headline)
                }
                if let version = scan.artifactVersion {
                    Text("v\(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(scan.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 8) {
                if scan.criticalCount > 0 {
                    SeverityPill(count: scan.criticalCount, label: " Critical", color: .red)
                }
                if scan.highCount > 0 {
                    SeverityPill(count: scan.highCount, label: " High", color: .orange)
                }
                if scan.mediumCount > 0 {
                    SeverityPill(count: scan.mediumCount, label: " Medium", color: .yellow)
                }
                if scan.lowCount > 0 {
                    SeverityPill(count: scan.lowCount, label: " Low", color: .blue)
                }
            }

            Text("\(scan.findingsCount) total findings")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = scan.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch scan.status {
        case "completed": return .green
        case "running", "pending": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }

    private func loadFindings() async {
        isLoading = findings.isEmpty
        do {
            findings = try await apiClient.listFindings(scanId: scan.id)
            errorMessage = nil
        } catch {
            if findings.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func acknowledge(_ finding: ScanFinding, reason: String) async {
        do {
            let updated = try await apiClient.acknowledgeFinding(id: finding.id, reason: reason)
            replace(updated)
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func revoke(_ finding: ScanFinding) async {
        do {
            let updated = try await apiClient.revokeFindingAcknowledgment(id: finding.id)
            replace(updated)
        } catch {
            actionError = error.localizedDescription
        }
    }

    /// Replace a finding in place so the row reflects the new acknowledgment state
    /// without a full reload.
    private func replace(_ updated: ScanFinding) {
        if let index = findings.firstIndex(where: { $0.id == updated.id }) {
            findings[index] = updated
        }
    }
}

// MARK: - Acknowledge Finding Sheet

/// Prompts for an acknowledgment reason before acknowledging a finding.
struct AcknowledgeFindingSheet: View {
    let finding: ScanFinding
    let onSubmit: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(finding.title)
                        .font(.headline)
                    if let cve = finding.cveId, !cve.isEmpty {
                        Text(cve)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Finding")
                }

                Section {
                    TextField("Reason", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Acknowledgment Reason")
                } footer: {
                    Text("Explain why this finding is accepted (for example, false positive or mitigated).")
                }
            }
            .navigationTitle("Acknowledge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Acknowledge") {
                        isSubmitting = true
                        Task {
                            await onSubmit(reason.trimmingCharacters(in: .whitespacesAndNewlines))
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
    }
}

// MARK: - Artifact SBOM

/// Shows the SBOM summary and component list for an artifact.
struct ArtifactSbomView: View {
    let artifactId: String
    let artifactName: String

    @State private var summary: SbomSummary?
    @State private var components: [SbomComponent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading SBOM...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await loadSbom() } }
                }
            } else if let summary {
                content(summary: summary)
            } else {
                ContentUnavailableView(
                    "No SBOM",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No software bill of materials has been generated for this artifact.")
                )
            }
        }
        .navigationTitle("SBOM")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await loadSbom() }
        .task { await loadSbom() }
    }

    @ViewBuilder
    private func content(summary: SbomSummary) -> some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statBox("Format", summary.format.uppercased(), sub: "v\(summary.formatVersion)")
                    statBox("Components", "\(summary.componentCount)")
                    statBox("Dependencies", "\(summary.dependencyCount)")
                    statBox("Licenses", "\(summary.licenseCount)")
                }
                .padding(.vertical, 4)

                if let generator = summary.generator {
                    HStack {
                        Text("Generated by")
                            .foregroundStyle(.secondary)
                        Text(generator + (summary.generatorVersion.map { " \($0)" } ?? ""))
                    }
                    .font(.caption)
                }
            }

            if !summary.licenses.isEmpty {
                Section("Licenses") {
                    ForEach(summary.licenses, id: \.self) { license in
                        Label(license, systemImage: "doc.plaintext")
                            .font(.subheadline)
                    }
                }
            }

            Section("Components (\(components.count))") {
                if components.isEmpty {
                    Text("No components recorded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(components) { component in
                        SbomComponentRow(component: component)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func statBox(_ label: String, _ value: String, sub: String? = nil) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func loadSbom() async {
        isLoading = summary == nil
        do {
            let fetched = try await apiClient.getSbomByArtifact(artifactId: artifactId)
            summary = fetched
            components = try await apiClient.getSbomComponents(sbomId: fetched.id)
            errorMessage = nil
        } catch {
            if summary == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

// MARK: - SBOM Component Row

struct SbomComponentRow: View {
    let component: SbomComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(component.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let version = component.version {
                    Text(version)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }

                Spacer()

                if let type = component.componentType {
                    Text(type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !component.licenses.isEmpty {
                Text(component.licenses.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let purl = component.purl, !purl.isEmpty {
                Text(purl)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Scan Detail") {
    NavigationStack {
        ArtifactScanDetailView(
            scan: ScanResult(
                id: "scan-1",
                artifactId: "art-1",
                scanType: "vulnerability",
                status: "completed",
                findingsCount: 3,
                criticalCount: 1,
                highCount: 1,
                mediumCount: 1,
                lowCount: 0,
                startedAt: nil,
                completedAt: nil,
                errorMessage: nil,
                artifactName: "libfoo",
                artifactVersion: "1.2.3"
            )
        )
    }
}

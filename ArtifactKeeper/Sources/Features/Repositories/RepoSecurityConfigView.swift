import SwiftUI

struct RepoSecurityConfigView: View {
    let repoKey: String

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveSuccess = false
    @State private var hasLoaded = false

    @State private var scanEnabled = false
    @State private var scanOnUpload = true
    @State private var scanOnProxy = false
    @State private var blockOnPolicyViolation = false
    @State private var severityThreshold = "high"

    @State private var recentScans: [ScanResult] = []
    @State private var isLoadingScans = true
    @State private var scansError: String?

    private let apiClient = APIClient.shared
    private let thresholds = ["critical", "high", "medium", "low"]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading security config\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, !hasLoaded {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                configForm
            }
        }
        .task { await loadConfig() }
        .task { await loadRecentScans() }
    }

    private var configForm: some View {
        Form {
            Section("Scanning") {
                Toggle("Enable Scanning", isOn: $scanEnabled)
                Toggle("Scan on Upload", isOn: $scanOnUpload)
                    .disabled(!scanEnabled)
                Toggle("Scan on Proxy", isOn: $scanOnProxy)
                    .disabled(!scanEnabled)
            }

            Section("Policy") {
                Toggle("Block on Policy Violation", isOn: $blockOnPolicyViolation)
                Picker("Severity Threshold", selection: $severityThreshold) {
                    ForEach(thresholds, id: \.self) { t in
                        Text(t.capitalized).tag(t)
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if saveSuccess {
                Section {
                    Label("Settings saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button {
                    Task { await saveConfig() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSaving ? "Saving\u{2026}" : "Save")
                    }
                }
                .disabled(isSaving)
            }

            recentScansSection
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var recentScansSection: some View {
        Section("Recent Scans") {
            if isLoadingScans {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading scans\u{2026}")
                        .foregroundStyle(.secondary)
                }
            } else if let scansError {
                Label(scansError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if recentScans.isEmpty {
                Text("No scans have run for this repository yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentScans) { scan in
                    RepoScanRow(scan: scan)
                }
            }
        }
    }

    private func loadConfig() async {
        isLoading = true
        errorMessage = nil

        do {
            let config = try await apiClient.getRepoSecurityConfig(repoKey: repoKey)
            scanEnabled = config.scanEnabled
            scanOnUpload = config.scanOnUpload
            scanOnProxy = config.scanOnProxy
            blockOnPolicyViolation = config.blockOnPolicyViolation
            severityThreshold = config.severityThreshold
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveConfig() async {
        isSaving = true
        errorMessage = nil
        saveSuccess = false

        let config = RepoSecurityConfig(
            scanEnabled: scanEnabled,
            scanOnUpload: scanOnUpload,
            scanOnProxy: scanOnProxy,
            blockOnPolicyViolation: blockOnPolicyViolation,
            severityThreshold: severityThreshold
        )

        do {
            _ = try await apiClient.updateRepoSecurityConfig(repoKey: repoKey, config: config)
            saveSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func loadRecentScans() async {
        isLoadingScans = recentScans.isEmpty
        do {
            recentScans = try await apiClient.listRepoScans(repoKey: repoKey)
            scansError = nil
        } catch {
            if recentScans.isEmpty {
                scansError = "Could not load recent scans."
            }
        }
        isLoadingScans = false
    }
}

private struct RepoScanRow: View {
    let scan: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(scan.artifactName ?? scan.artifactId)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let version = scan.artifactVersion, !version.isEmpty {
                    Text(version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(scan.status.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 6) {
                if scan.criticalCount > 0 {
                    severityPill(scan.criticalCount, "C", .red)
                }
                if scan.highCount > 0 {
                    severityPill(scan.highCount, "H", .orange)
                }
                if scan.mediumCount > 0 {
                    severityPill(scan.mediumCount, "M", .yellow)
                }
                if scan.lowCount > 0 {
                    severityPill(scan.lowCount, "L", .blue)
                }
                if scan.findingsCount == 0 && scan.status.lowercased() == "completed" {
                    Text("No findings")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var statusIcon: String {
        switch scan.status.lowercased() {
        case "completed": return "checkmark.circle.fill"
        case "failed", "error": return "xmark.circle.fill"
        case "running", "in_progress", "pending": return "clock.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch scan.status.lowercased() {
        case "completed": return scan.findingsCount > 0 ? .orange : .green
        case "failed", "error": return .red
        case "running", "in_progress", "pending": return .blue
        default: return .secondary
        }
    }

    private func severityPill(_ count: Int, _ label: String, _ color: Color) -> some View {
        Text("\(count)\(label)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

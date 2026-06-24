import SwiftUI

/// Read-only listing of per-repository scan configurations
/// (GET /api/v1/security/configs). The configs are authored per repository
/// from the repository detail Security tab; this view surfaces them all in one
/// place so an operator can audit which repositories have scanning enabled and
/// how their thresholds are set.
struct ScanConfigsView: View {
    @State private var configs: [ScanConfig] = []
    @State private var repoNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading scan configurations\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Configurations Unavailable", systemImage: "gearshape.2")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if configs.isEmpty {
                ContentUnavailableView(
                    "No Scan Configurations",
                    systemImage: "gearshape.2",
                    description: Text("No repository has a scan configuration yet. Enable scanning from a repository's Security tab.")
                )
            } else {
                List {
                    ForEach(configs) { config in
                        ScanConfigRow(
                            config: config,
                            repositoryName: repoNames[config.repositoryId]
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = configs.isEmpty
        do {
            // Resolve repository ids to names in parallel so the rows can show a
            // human-readable label instead of a bare UUID.
            async let configsResult = apiClient.listScanConfigs()
            async let reposResult = apiClient.listRepositories()
            let loaded = try await configsResult
            let repos = (try? await reposResult) ?? []

            configs = loaded.sorted { lhs, rhs in
                let l = repoNames[lhs.repositoryId] ?? lhs.repositoryId
                let r = repoNames[rhs.repositoryId] ?? rhs.repositoryId
                return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
            }
            repoNames = Dictionary(uniqueKeysWithValues: repos.map { ($0.id, $0.name) })
            errorMessage = nil
        } catch {
            if configs.isEmpty {
                errorMessage = "Could not load scan configurations. You may need admin privileges."
            }
        }
        isLoading = false
    }
}

private struct ScanConfigRow: View {
    let config: ScanConfig
    let repositoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: config.scanEnabled ? "checkmark.shield.fill" : "shield.slash")
                    .foregroundStyle(config.scanEnabled ? Color.green : Color.secondary)
                Text(repositoryName ?? config.repositoryId)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(config.scanEnabled ? "Enabled" : "Disabled")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(config.scanEnabled ? Color.green : Color.secondary)
            }

            HStack(spacing: 8) {
                if config.scanOnUpload {
                    ScanConfigTag(text: "On Upload", systemImage: "arrow.up.doc")
                }
                if config.scanOnProxy {
                    ScanConfigTag(text: "On Proxy", systemImage: "arrow.down.circle")
                }
                if config.blockOnPolicyViolation {
                    ScanConfigTag(text: "Blocks Violations", systemImage: "hand.raised")
                }
            }

            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(severityColor)
                Text("Threshold: \(config.severityThreshold.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var severityColor: Color {
        switch config.severityThreshold.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .secondary
        }
    }
}

private struct ScanConfigTag: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }
}

import SwiftUI

struct ReplicationView: View {
    @State private var rules: [ReplicationRule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading replication rules...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Replication Unavailable",
                    systemImage: "arrow.triangle.2.circlepath.circle",
                    description: Text(error)
                )
            } else if rules.isEmpty {
                ContentUnavailableView(
                    "No Replication Rules",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Configure replication rules from the web interface to sync artifacts between instances.")
                )
            } else {
                List(rules) { rule in
                    ReplicationRuleRow(rule: rule)
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadRules() }
        .task { await loadRules() }
    }

    private func loadRules() async {
        isLoading = rules.isEmpty
        do {
            let response: ReplicationRuleListResponse = try await apiClient.request("/api/v1/replication/rules")
            rules = response.items
            errorMessage = nil
        } catch {
            if rules.isEmpty {
                errorMessage = "Could not load replication rules. This feature may not be available on your server."
            }
        }
        isLoading = false
    }
}

struct ReplicationRuleRow: View {
    let rule: ReplicationRule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rule.name)
                    .font(.body.weight(.medium))
                Spacer()
                if rule.enabled {
                    Text("Enabled")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.1), in: Capsule())
                        .foregroundStyle(.green)
                } else {
                    Text("Disabled")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 4) {
                Text(rule.sourceRepoKey)
                    .font(.caption)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(rule.targetRepoKey)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            if let status = rule.lastRunStatus {
                Text("Last run: \(status)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

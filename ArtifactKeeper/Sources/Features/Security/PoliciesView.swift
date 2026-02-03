import SwiftUI

struct PoliciesView: View {
    @State private var policies: [SecurityPolicy] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading policies...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Policies Unavailable",
                    systemImage: "lock.shield",
                    description: Text(error)
                )
            } else if policies.isEmpty {
                ContentUnavailableView(
                    "No Security Policies",
                    systemImage: "shield",
                    description: Text("Configure security policies from the web interface to enforce compliance rules.")
                )
            } else {
                List(policies) { policy in
                    PolicyRow(policy: policy)
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadPolicies() }
        .task { await loadPolicies() }
    }

    private func loadPolicies() async {
        isLoading = policies.isEmpty
        do {
            let response: SecurityPolicyListResponse = try await apiClient.request("/api/v1/security/policies")
            policies = response.items
            errorMessage = nil
        } catch {
            if policies.isEmpty {
                errorMessage = "Could not load security policies. This feature may not be available on your server."
            }
        }
        isLoading = false
    }
}

struct PolicyRow: View {
    let policy: SecurityPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(policy.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(policy.policyType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.purple.opacity(0.1), in: Capsule())
                    .foregroundStyle(.purple)
            }
            if let desc = policy.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                Text(policy.enabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(policy.enabled ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

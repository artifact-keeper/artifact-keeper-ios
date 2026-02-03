import SwiftUI

struct PoliciesView: View {
    @State private var policies: [SecurityPolicy] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddPolicy = false

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
            } else {
                VStack(spacing: 0) {
                    if policies.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No Security Policies",
                            systemImage: "shield",
                            description: Text("No policies configured yet.")
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(policies) { policy in
                                PolicyRow(
                                    policy: policy,
                                    onToggle: { await togglePolicy(policy) },
                                    onDelete: { await deletePolicy(policy) }
                                )
                            }
                        }
                        .listStyle(.plain)
                    }

                    Divider()
                    Button {
                        showingAddPolicy = true
                    } label: {
                        Label("Add Policy", systemImage: "plus.circle")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 16)
                }
            }
        }
        .refreshable { await loadPolicies() }
        .task { await loadPolicies() }
        .sheet(isPresented: $showingAddPolicy) {
            NavigationStack {
                AddPolicyView { await loadPolicies() }
                    .navigationTitle("Add Policy")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    private func loadPolicies() async {
        isLoading = policies.isEmpty
        do {
            // Backend returns a plain array, not wrapped in { items: [...] }
            let response: [SecurityPolicy] = try await apiClient.request("/api/v1/security/policies")
            policies = response
            errorMessage = nil
        } catch {
            if policies.isEmpty {
                errorMessage = "Could not load security policies. You may need admin privileges."
            }
        }
        isLoading = false
    }

    private func togglePolicy(_ policy: SecurityPolicy) async {
        do {
            let body = UpdatePolicyBody(
                name: policy.name,
                max_severity: policy.maxSeverity,
                block_unscanned: policy.blockUnscanned,
                block_on_fail: policy.blockOnFail,
                is_enabled: !policy.isEnabled
            )
            let _: SecurityPolicy = try await apiClient.request(
                "/api/v1/security/policies/\(policy.id)",
                method: "PUT",
                body: body
            )
            await loadPolicies()
        } catch {
            // silent
        }
    }

    private func deletePolicy(_ policy: SecurityPolicy) async {
        do {
            try await apiClient.requestVoid(
                "/api/v1/security/policies/\(policy.id)",
                method: "DELETE"
            )
            policies.removeAll { $0.id == policy.id }
        } catch {
            // silent
        }
    }
}

private struct UpdatePolicyBody: Encodable {
    let name: String
    let max_severity: String
    let block_unscanned: Bool
    let block_on_fail: Bool
    let is_enabled: Bool
}

struct PolicyRow: View {
    let policy: SecurityPolicy
    let onToggle: () async -> Void
    let onDelete: () async -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(policy.name)
                    .font(.body.weight(.medium))
                Spacer()
                Button {
                    Task { await onToggle() }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(policy.isEnabled ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(policy.isEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(policy.isEnabled ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Label(policy.maxSeverity.capitalized, systemImage: "exclamationmark.shield")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(severityColor)

                if policy.blockUnscanned {
                    Text("Block unscanned")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.1), in: Capsule())
                        .foregroundStyle(.orange)
                }

                if policy.blockOnFail {
                    Text("Block on fail")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.1), in: Capsule())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button { Task { await onToggle() } } label: {
                Label(policy.isEnabled ? "Disable" : "Enable",
                      systemImage: policy.isEnabled ? "pause.circle" : "play.circle")
            }
            Divider()
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Policy", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await onDelete() } }
        } message: {
            Text("Delete \"\(policy.name)\"? This cannot be undone.")
        }
    }

    private var severityColor: Color {
        switch policy.maxSeverity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .purple
        }
    }
}

// MARK: - Add Policy Sheet

private let severityLevels = ["critical", "high", "medium", "low"]

private struct CreatePolicyBody: Encodable {
    let name: String
    let repository_id: String?
    let max_severity: String
    let block_unscanned: Bool
    let block_on_fail: Bool
}

struct AddPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var maxSeverity = "high"
    @State private var blockUnscanned = false
    @State private var blockOnFail = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared
    var onSaved: () async -> Void

    var body: some View {
        Form {
            Section("Policy Info") {
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
            }

            Section {
                Picker("Max Severity", selection: $maxSeverity) {
                    ForEach(severityLevels, id: \.self) { level in
                        Text(level.capitalized).tag(level)
                    }
                }
            } header: {
                Text("Threshold")
            } footer: {
                Text("Artifacts with findings at or above this severity level will be blocked.")
            }

            Section("Options") {
                Toggle("Block unscanned artifacts", isOn: $blockUnscanned)
                Toggle("Block on scan failure", isOn: $blockOnFail)
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await createPolicy() } }
                    .disabled(isSaving || name.isEmpty)
            }
        }
    }

    private func createPolicy() async {
        isSaving = true
        errorMessage = nil
        do {
            let body = CreatePolicyBody(
                name: name.trimmingCharacters(in: .whitespaces),
                repository_id: nil,
                max_severity: maxSeverity,
                block_unscanned: blockUnscanned,
                block_on_fail: blockOnFail
            )
            let _: SecurityPolicy = try await apiClient.request(
                "/api/v1/security/policies",
                method: "POST",
                body: body
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = "Failed to create policy: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

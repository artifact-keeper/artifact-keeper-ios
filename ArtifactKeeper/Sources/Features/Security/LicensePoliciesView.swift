import SwiftUI

struct LicensePoliciesView: View {
    @State private var policies: [LicensePolicy] = []
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
                    systemImage: "doc.badge.gearshape",
                    description: Text(error)
                )
            } else {
                VStack(spacing: 0) {
                    if policies.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No License Policies",
                            systemImage: "doc.badge.gearshape",
                            description: Text("No license policies configured yet.")
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(policies) { policy in
                                LicensePolicyRow(
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
                        Label("Add License Policy", systemImage: "plus.circle")
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
                AddLicensePolicyView { await loadPolicies() }
                    .navigationTitle("Add License Policy")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    private func loadPolicies() async {
        isLoading = policies.isEmpty
        do {
            let response: [LicensePolicy] = try await apiClient.request("/api/v1/sbom/license-policies")
            policies = response
            errorMessage = nil
        } catch {
            if policies.isEmpty {
                errorMessage = "Could not load license policies. You may need admin privileges."
            }
        }
        isLoading = false
    }

    private func togglePolicy(_ policy: LicensePolicy) async {
        do {
            let body = CreateLicensePolicyRequest(
                repositoryId: policy.repositoryId,
                name: policy.name,
                description: policy.description,
                allowedLicenses: policy.allowedLicenses,
                deniedLicenses: policy.deniedLicenses,
                allowUnknown: policy.allowUnknown,
                action: policy.action,
                isEnabled: !policy.isEnabled
            )
            let _: LicensePolicy = try await apiClient.request(
                "/api/v1/sbom/license-policies",
                method: "POST",
                body: body
            )
            await loadPolicies()
        } catch {
            // silent
        }
    }

    private func deletePolicy(_ policy: LicensePolicy) async {
        do {
            try await apiClient.requestVoid(
                "/api/v1/sbom/license-policies/\(policy.id)",
                method: "DELETE"
            )
            policies.removeAll { $0.id == policy.id }
        } catch {
            // silent
        }
    }
}

struct LicensePolicyRow: View {
    let policy: LicensePolicy
    let onToggle: () async -> Void
    let onDelete: () async -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if let desc = policy.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Label(policy.action.capitalized, systemImage: actionIcon)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(actionColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(actionColor)

                if !policy.allowedLicenses.isEmpty {
                    Text("\(policy.allowedLicenses.count) allowed")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1), in: Capsule())
                        .foregroundStyle(.green)
                }

                if !policy.deniedLicenses.isEmpty {
                    Text("\(policy.deniedLicenses.count) denied")
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

    private var actionIcon: String {
        switch policy.action.lowercased() {
        case "allow": return "checkmark.shield"
        case "warn": return "exclamationmark.triangle"
        case "block": return "xmark.shield"
        default: return "questionmark.circle"
        }
    }

    private var actionColor: Color {
        switch policy.action.lowercased() {
        case "allow": return .green
        case "warn": return .yellow
        case "block": return .red
        default: return .purple
        }
    }
}

// MARK: - Add License Policy Sheet

private let actionOptions = ["allow", "warn", "block"]

struct AddLicensePolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var allowedLicenses = ""
    @State private var deniedLicenses = ""
    @State private var allowUnknown = true
    @State private var action = "warn"
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared
    var onSaved: () async -> Void

    var body: some View {
        Form {
            Section("Policy Info") {
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
                TextField("Description (optional)", text: $description)
            }

            Section {
                TextField("Allowed Licenses", text: $allowedLicenses)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            } header: {
                Text("Allowed Licenses")
            } footer: {
                Text("Comma-separated list (e.g., MIT, Apache-2.0, BSD-3-Clause). Leave empty to allow any.")
            }

            Section {
                TextField("Denied Licenses", text: $deniedLicenses)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            } header: {
                Text("Denied Licenses")
            } footer: {
                Text("Comma-separated list (e.g., GPL-3.0, AGPL-3.0)")
            }

            Section {
                Picker("Action on Violation", selection: $action) {
                    ForEach(actionOptions, id: \.self) { opt in
                        HStack {
                            Image(systemName: actionIcon(for: opt))
                                .foregroundStyle(actionColor(for: opt))
                            Text(opt.capitalized)
                        }
                        .tag(opt)
                    }
                }
            } footer: {
                Text("Action to take when a license violation is detected.")
            }

            Section("Options") {
                Toggle("Allow unknown licenses", isOn: $allowUnknown)
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

    private func actionIcon(for action: String) -> String {
        switch action {
        case "allow": return "checkmark.shield"
        case "warn": return "exclamationmark.triangle"
        case "block": return "xmark.shield"
        default: return "questionmark.circle"
        }
    }

    private func actionColor(for action: String) -> Color {
        switch action {
        case "allow": return .green
        case "warn": return .yellow
        case "block": return .red
        default: return .purple
        }
    }

    private func createPolicy() async {
        isSaving = true
        errorMessage = nil
        do {
            let allowed = allowedLicenses
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let denied = deniedLicenses
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let body = CreateLicensePolicyRequest(
                repositoryId: nil,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                allowedLicenses: allowed,
                deniedLicenses: denied,
                allowUnknown: allowUnknown,
                action: action,
                isEnabled: true
            )
            let _: LicensePolicy = try await apiClient.request(
                "/api/v1/sbom/license-policies",
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

#Preview {
    NavigationStack {
        LicensePoliciesView()
            .navigationTitle("License Policies")
    }
}

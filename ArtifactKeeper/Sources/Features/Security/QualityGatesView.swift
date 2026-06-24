import SwiftUI

/// Quality gate definitions (GET /api/v1/quality/gates). Tapping a gate opens a
/// detail screen that re-fetches the single gate by id
/// (GET /api/v1/quality/gates/{id}) and lets the operator evaluate it against an
/// artifact (POST /api/v1/quality/gates/evaluate/{artifact_id}).
struct QualityGatesView: View {
    @State private var gates: [QualityGate] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading quality gates\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Gates Unavailable", systemImage: "checkmark.seal")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if gates.isEmpty {
                ContentUnavailableView(
                    "No Quality Gates",
                    systemImage: "checkmark.seal",
                    description: Text("No quality gates are configured yet.")
                )
            } else {
                List {
                    ForEach(gates) { gate in
                        NavigationLink {
                            QualityGateDetailView(listGate: gate)
                        } label: {
                            QualityGateRow(gate: gate)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = gates.isEmpty
        do {
            gates = try await apiClient.listQualityGates()
            errorMessage = nil
        } catch {
            if gates.isEmpty {
                errorMessage = "Could not load quality gates. You may need admin privileges."
            }
        }
        isLoading = false
    }
}

private struct QualityGateRow: View {
    let gate: QualityGate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: gate.isEnabled ? "checkmark.seal.fill" : "seal")
                    .foregroundStyle(gate.isEnabled ? Color.green : Color.secondary)
                Text(gate.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(gate.action.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let description = gate.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 8) {
                if gate.enforceOnPromotion {
                    GateTag(text: "Promotion", systemImage: "arrow.up.circle")
                }
                if gate.enforceOnDownload {
                    GateTag(text: "Download", systemImage: "arrow.down.circle")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct GateTag: View {
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

/// Detail for one gate. Re-fetches the gate by id on appear so a stale list value
/// is refreshed, and offers an evaluation sheet.
struct QualityGateDetailView: View {
    let listGate: QualityGate

    @State private var fetched: QualityGate?
    @State private var loadError: String?
    @State private var showingEvaluate = false

    private let apiClient = APIClient.shared

    private var gate: QualityGate { fetched ?? listGate }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Gate") {
                detailRow("Name", gate.name)
                detailRow("Action", gate.action.capitalized)
                detailRow("Enabled", gate.isEnabled ? "Yes" : "No")
                detailRow("Enforce on Promotion", gate.enforceOnPromotion ? "Yes" : "No")
                detailRow("Enforce on Download", gate.enforceOnDownload ? "Yes" : "No")
            }

            if let description = gate.description, !description.isEmpty {
                Section("Description") {
                    Text(description).font(.subheadline)
                }
            }

            if !gate.requiredChecks.isEmpty {
                Section("Required Checks") {
                    ForEach(gate.requiredChecks, id: \.self) { check in
                        Label(check, systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }
            }

            Section("Thresholds") {
                thresholdRow("Min Health Score", gate.minHealthScore)
                thresholdRow("Min Quality Score", gate.minQualityScore)
                thresholdRow("Min Security Score", gate.minSecurityScore)
                thresholdRow("Min Metadata Score", gate.minMetadataScore)
                thresholdRow("Max Critical Issues", gate.maxCriticalIssues)
                thresholdRow("Max High Issues", gate.maxHighIssues)
                thresholdRow("Max Medium Issues", gate.maxMediumIssues)
            }

            Section {
                Button {
                    showingEvaluate = true
                } label: {
                    Label("Evaluate Against Artifact", systemImage: "play.circle")
                }
            }
        }
        .navigationTitle(gate.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
        .sheet(isPresented: $showingEvaluate) {
            NavigationStack {
                GateEvaluateView(gate: gate)
            }
        }
    }

    private func loadDetail() async {
        do {
            fetched = try await apiClient.getQualityGate(id: listGate.id)
            loadError = nil
        } catch {
            loadError = "Showing cached details; could not refresh: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func thresholdRow(_ label: String, _ value: Int?) -> some View {
        if let value {
            detailRow(label, "\(value)")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

/// Sheet that runs `evaluateGate` for an artifact id the operator types in.
struct GateEvaluateView: View {
    let gate: QualityGate

    @Environment(\.dismiss) private var dismiss
    @State private var artifactId = ""
    @State private var isEvaluating = false
    @State private var result: GateEvaluation?
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Form {
            Section("Artifact") {
                TextField("Artifact ID", text: $artifactId)
                    .textContentType(.none)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
            }

            Section {
                Button {
                    Task { await evaluate() }
                } label: {
                    if isEvaluating {
                        ProgressView()
                    } else {
                        Text("Evaluate")
                    }
                }
                .disabled(artifactId.trimmingCharacters(in: .whitespaces).isEmpty || isEvaluating)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if let result {
                Section("Result") {
                    HStack {
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.passed ? Color.green : Color.red)
                        Text(result.passed ? "Passed" : "Failed")
                            .font(.headline)
                        Spacer()
                        Text(result.action.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    detailRow("Gate", result.gateName)
                    detailRow("Health Score", "\(result.healthScore)")
                    detailRow("Health Grade", result.healthGrade)
                }

                if !result.componentScores.isEmpty {
                    Section("Component Scores") {
                        ForEach(result.componentScores.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            detailRow(key.capitalized, "\(value)")
                        }
                    }
                }

                if !result.violations.isEmpty {
                    Section("Violations") {
                        ForEach(result.violations) { violation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(violation.rule)
                                    .font(.subheadline.weight(.semibold))
                                Text(violation.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Expected \(violation.expected), got \(violation.actual)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Evaluate Gate")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func evaluate() async {
        isEvaluating = true
        errorMessage = nil
        defer { isEvaluating = false }
        let trimmed = artifactId.trimmingCharacters(in: .whitespaces)
        do {
            result = try await apiClient.evaluateGate(
                artifactId: trimmed,
                repositoryId: gate.repositoryId
            )
        } catch {
            errorMessage = "Evaluation failed: \(error.localizedDescription)"
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

import SwiftUI

/// Single CVE history record detail. On appearance it re-fetches the record by id
/// via APIClient.getCveHistory(id:) (GET /api/v1/sbom/cve/history/{id}) and renders
/// the fetched value rather than reusing the list row. It also exposes a triage
/// status change (open / acknowledged / false_positive / fixed + optional reason)
/// via update_cve_status_by_artifact_cve, matching the Android operate action.
struct CveHistoryDetailView: View {
    /// The entry as known from the list, shown immediately while the by-id fetch
    /// is in flight and used as the source of the runtime ids.
    let listEntry: CveHistoryEntry

    @State private var fetched: CveHistoryEntry?
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var selectedStatus: CveStatus = .open
    @State private var reason = ""
    @State private var isSaving = false
    @State private var statusAlert: StatusAlert?

    private let apiClient = APIClient.shared

    /// The freshest record we have: the by-id fetch if it succeeded, else the list value.
    private var entry: CveHistoryEntry { fetched ?? listEntry }

    var body: some View {
        Form {
            if isLoading && fetched == nil {
                Section {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Loading record\u{2026}").foregroundStyle(.secondary)
                    }
                }
            } else if let loadError, fetched == nil {
                Section {
                    ContentUnavailableView {
                        Label("Could Not Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                detailSections
            }
        }
        .navigationTitle(entry.cveId)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .refreshable { await load() }
        .alert(item: $statusAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder
    private var detailSections: some View {
        Section("Vulnerability") {
            detailRow("CVE", entry.cveId)
            if let severity = entry.severity {
                detailRow("Severity", severity.capitalized)
            }
            if let score = entry.cvssScore {
                detailRow("CVSS", String(format: "%.1f", score))
            }
            detailRow("Status", (CveStatus(rawValue: entry.status)?.label ?? entry.status.capitalized))
            if let component = entry.affectedComponent {
                detailRow("Component", "\(component)\(entry.affectedVersion.map { " @ \($0)" } ?? "")")
            }
            if let fixed = entry.fixedVersion, !fixed.isEmpty {
                detailRow("Fixed In", fixed)
            }
        }

        if let url = URL(string: "https://nvd.nist.gov/vuln/detail/\(entry.cveId)") {
            Section {
                Link(destination: url) {
                    Label("View on NVD", systemImage: "arrow.up.right.square")
                }
            }
        }

        Section("Set Status") {
            Picker("Status", selection: $selectedStatus) {
                ForEach(CveStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(status)
                }
            }
            TextField("Reason (optional)", text: $reason, axis: .vertical)
                .lineLimit(1...3)
            Button {
                Task { await applyStatus() }
            } label: {
                if isSaving {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Saving\u{2026}")
                    }
                } else {
                    Text("Update Status")
                }
            }
            .disabled(isSaving || selectedStatus.rawValue == entry.status)
        }
    }

    private func load() async {
        isLoading = fetched == nil
        do {
            let record = try await apiClient.getCveHistory(id: listEntry.id)
            fetched = record
            selectedStatus = CveStatus(rawValue: record.status) ?? .open
            loadError = nil
        } catch {
            if fetched == nil {
                loadError = "Could not load this record: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }

    private func applyStatus() async {
        isSaving = true
        defer { isSaving = false }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            // Runtime ids come from the fetched record, not a hand-built path.
            let updated = try await apiClient.updateCveStatusByArtifactCve(
                artifactId: entry.artifactId,
                cveId: entry.cveId,
                status: selectedStatus.rawValue,
                reason: trimmed.isEmpty ? nil : trimmed
            )
            fetched = updated
            selectedStatus = CveStatus(rawValue: updated.status) ?? selectedStatus
            reason = ""
            statusAlert = StatusAlert(title: "Status Updated", message: "\(entry.cveId) is now \(selectedStatus.label).")
        } catch {
            statusAlert = StatusAlert(title: "Update Failed", message: error.localizedDescription)
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

private struct StatusAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

import SwiftUI

/// Detail for a single CVE history record. Opened from a row in CveHistoryView.
///
/// On appearance it re-fetches the record by id via APIClient.getCveHistory(id:)
/// (GET /api/v1/sbom/cve/history/{id}) rather than reusing the list row, so the
/// detail always shows the current server state. The operator can change the
/// triage status, which posts to
/// /api/v1/sbom/cve/status/by-artifact/{artifact_id}/by-cve/{cve_id} and updates
/// the displayed record with the response.
struct CveHistoryDetailView: View {
    /// The id of the history record to load. The artifact id and CVE id used for
    /// the status mutation come from the fetched record, not from the list row.
    let entryId: String

    @State private var entry: CveHistoryEntry?
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var selectedStatus: CveStatus = .open
    @State private var reason = ""
    @State private var isSaving = false
    @State private var statusAlert: StatusAlert?

    private let apiClient = APIClient.shared

    /// Result of a status-change attempt, surfaced as an alert.
    private struct StatusAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                ContentUnavailableView {
                    Label("Could Not Load Record", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if let entry {
                detail(for: entry)
            }
        }
        .navigationTitle("CVE Detail")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .alert(item: $statusAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private func detail(for entry: CveHistoryEntry) -> some View {
        Form {
            Section("Vulnerability") {
                LabeledContent("CVE") {
                    Link(entry.cveId, destination: URL(string: "https://nvd.nist.gov/vuln/detail/\(entry.cveId)")!)
                }
                if let severity = entry.severity {
                    LabeledContent("Severity", value: severity.capitalized)
                }
                if let score = entry.cvssScore {
                    LabeledContent("CVSS", value: String(format: "%.1f", score))
                }
                LabeledContent("Current status", value: statusLabel(entry.status))
            }

            Section("Affected") {
                if let component = entry.affectedComponent {
                    LabeledContent("Component", value: component)
                }
                if let version = entry.affectedVersion {
                    LabeledContent("Version", value: version)
                }
                if let fixed = entry.fixedVersion, !fixed.isEmpty {
                    LabeledContent("Fixed in", value: fixed)
                }
            }

            Section("Timeline") {
                LabeledContent("First detected", value: formattedDate(entry.firstDetectedAt))
                LabeledContent("Last detected", value: formattedDate(entry.lastDetectedAt))
                if let ackBy = entry.acknowledgedBy {
                    LabeledContent("Acknowledged by", value: ackBy)
                }
                if let ackReason = entry.acknowledgedReason, !ackReason.isEmpty {
                    LabeledContent("Reason", value: ackReason)
                }
            }

            Section("Set status") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(CveStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
                TextField("Reason (optional)", text: $reason, axis: .vertical)
                    .lineLimit(1...3)
                Button {
                    Task { await applyStatus(for: entry) }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Update status")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || selectedStatus.rawValue == entry.status)
            }
        }
        #if os(iOS)
        .formStyle(.grouped)
        #endif
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let fetched = try await apiClient.getCveHistory(id: entryId)
            entry = fetched
            selectedStatus = CveStatus(rawValue: fetched.status) ?? .open
        } catch {
            entry = nil
            loadError = "Could not load this record: \(error.localizedDescription)"
        }
    }

    private func applyStatus(for entry: CveHistoryEntry) async {
        isSaving = true
        defer { isSaving = false }
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let updated = try await apiClient.updateCveStatusByArtifactCve(
                artifactId: entry.artifactId,
                cveId: entry.cveId,
                status: selectedStatus.rawValue,
                reason: trimmedReason.isEmpty ? nil : trimmedReason
            )
            self.entry = updated
            selectedStatus = CveStatus(rawValue: updated.status) ?? selectedStatus
            statusAlert = StatusAlert(
                title: "Status updated",
                message: "\(updated.cveId) is now \(statusLabel(updated.status))."
            )
        } catch {
            // Non-destructive: keep the displayed record as-is and report the failure.
            statusAlert = StatusAlert(
                title: "Update failed",
                message: error.localizedDescription
            )
        }
    }

    private func statusLabel(_ status: String) -> String {
        CveStatus(rawValue: status)?.label ?? status.capitalized
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return dateString
    }
}

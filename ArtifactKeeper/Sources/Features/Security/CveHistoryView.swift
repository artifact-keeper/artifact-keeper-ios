import SwiftUI

/// CVE history lookup. The operator chooses to search by CVE id (across all
/// artifacts, GET /api/v1/sbom/cve/history/by-cve/{cve_id}) or by artifact id
/// (GET /api/v1/sbom/cve/history/by-artifact/{artifact_id}), and the matching
/// history entries are listed.
struct CveHistoryView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case byCve = "By CVE"
        case byArtifact = "By Artifact"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .byCve
    @State private var query = ""
    @State private var entries: [CveHistoryEntry] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            Picker("Search by", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .onChange(of: mode) { _, _ in
                entries = []
                hasSearched = false
                errorMessage = nil
            }

            HStack {
                TextField(placeholder, text: $query)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(mode == .byCve ? .allCharacters : .none)
                    .disableAutocorrection(true)
                    #endif
                    .onSubmit { Task { await search() } }
                Button {
                    Task { await search() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            content
        }
    }

    private var placeholder: String {
        mode == .byCve ? "CVE id (e.g. CVE-2024-1234)" : "Artifact id"
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Searching\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Lookup Failed", systemImage: "exclamationmark.magnifyingglass")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await search() } }
                    .buttonStyle(.borderedProminent)
            }
        } else if !hasSearched {
            ContentUnavailableView(
                "Search CVE History",
                systemImage: "clock.arrow.circlepath",
                description: Text("Enter a \(mode == .byCve ? "CVE id" : "artifact id") to look up its vulnerability history.")
            )
        } else if entries.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "checkmark.shield",
                description: Text("No CVE history found for that \(mode == .byCve ? "CVE" : "artifact").")
            )
        } else {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        CveHistoryDetailView(listEntry: entry)
                    } label: {
                        CveHistoryEntryRow(entry: entry)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }
        do {
            switch mode {
            case .byCve:
                entries = try await apiClient.getCveHistoryByCve(cveId: trimmed)
            case .byArtifact:
                entries = try await apiClient.getCveHistoryByArtifact(artifactId: trimmed)
            }
        } catch {
            entries = []
            errorMessage = "Could not load CVE history: \(error.localizedDescription)"
        }
    }
}

private struct CveHistoryEntryRow: View {
    let entry: CveHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.cveId)
                    .font(.subheadline.weight(.semibold))
                if let severity = entry.severity {
                    Text(severity.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(severityColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(severityColor)
                }
                Spacer()
                Text(entry.status.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }

            if let component = entry.affectedComponent {
                Text("\(component)\(entry.affectedVersion.map { " @ \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let fixed = entry.fixedVersion, !fixed.isEmpty {
                Text("Fixed in \(fixed)")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            HStack {
                if let score = entry.cvssScore {
                    Text("CVSS \(String(format: "%.1f", score))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("First seen \(formattedDate(entry.firstDetectedAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var severityColor: Color {
        switch entry.severity?.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .secondary
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            return display.string(from: date)
        }
        return dateString
    }
}

import SwiftUI

/// Lists migration jobs (GET /api/v1/migrations) and lets an operator inspect a
/// job (GET /api/v1/migrations/{id}) and drive its lifecycle
/// (start / pause / resume / cancel). Connection and job authoring is deferred to
/// the web UI; this surface is read + lifecycle control.
struct MigrationsView: View {
    @State private var jobs: [MigrationJob] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading migrations\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Migrations Unavailable", systemImage: "arrow.left.arrow.right")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if jobs.isEmpty {
                ContentUnavailableView(
                    "No Migrations",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("No migration jobs have been created.")
                )
            } else {
                List {
                    ForEach(jobs) { job in
                        NavigationLink {
                            MigrationDetailView(listJob: job)
                        } label: {
                            MigrationRow(job: job)
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
        isLoading = jobs.isEmpty
        do {
            jobs = try await apiClient.listMigrations()
                .sorted { $0.createdAt > $1.createdAt }
            errorMessage = nil
        } catch {
            if jobs.isEmpty {
                errorMessage = "Could not load migrations. This feature may not be available on your server."
            }
        }
        isLoading = false
    }
}

/// Shared status color so the list and detail agree.
func migrationStatusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "completed", "succeeded": return .green
    case "running", "in_progress": return .blue
    case "paused": return .orange
    case "failed", "error": return .red
    case "cancelled", "canceled": return .secondary
    default: return .secondary
    }
}

private struct MigrationRow: View {
    let job: MigrationJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.jobType.capitalized)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(job.status.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(migrationStatusColor(job.status))
            }
            ProgressView(value: min(max(job.progressPercent / 100, 0), 1))
                .tint(migrationStatusColor(job.status))
            Text("\(job.completedItems)/\(job.totalItems) items \u{00B7} \(Int(job.progressPercent))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Detail for one migration. Re-fetches by id on appear and offers lifecycle
/// actions appropriate to the current status.
struct MigrationDetailView: View {
    let listJob: MigrationJob

    @State private var fetched: MigrationJob?
    @State private var loadError: String?
    @State private var isMutating = false
    @State private var actionMessage: (success: Bool, text: String)?
    @State private var pendingCancel = false

    private let apiClient = APIClient.shared

    private var job: MigrationJob { fetched ?? listJob }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let actionMessage {
                Section {
                    Label(actionMessage.text, systemImage: actionMessage.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(actionMessage.success ? .green : .red)
                }
            }

            Section("Status") {
                detailRow("Status", job.status.capitalized)
                detailRow("Type", job.jobType.capitalized)
                HStack {
                    Text("Progress").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(job.progressPercent))%")
                }
                .font(.subheadline)
                ProgressView(value: min(max(job.progressPercent / 100, 0), 1))
                    .tint(migrationStatusColor(job.status))
            }

            Section("Items") {
                detailRow("Total", "\(job.totalItems)")
                detailRow("Completed", "\(job.completedItems)")
                detailRow("Failed", "\(job.failedItems)")
                detailRow("Skipped", "\(job.skippedItems)")
            }

            Section("Transfer") {
                detailRow("Transferred", byteString(job.transferredBytes))
                detailRow("Total Size", byteString(job.totalBytes))
                if let eta = job.estimatedTimeRemaining {
                    detailRow("Est. Remaining", "\(eta)s")
                }
            }

            if let error = job.errorSummary, !error.isEmpty {
                Section("Error") {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            lifecycleSection
        }
        .navigationTitle(job.jobType.capitalized)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
        .confirmationDialog(
            "Cancel this migration?",
            isPresented: $pendingCancel,
            titleVisibility: .visible
        ) {
            Button("Cancel Migration", role: .destructive) {
                Task { await act("cancelled") { try await apiClient.cancelMigration(id: job.id) } }
            }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("This stops the migration. In-progress items may be left partially transferred.")
        }
    }

    @ViewBuilder
    private var lifecycleSection: some View {
        let status = job.status.lowercased()
        Section("Actions") {
            if status == "pending" || status == "created" {
                actionButton("Start", "play.circle") {
                    await act("started") { try await apiClient.startMigration(id: job.id) }
                }
            }
            if status == "running" || status == "in_progress" {
                actionButton("Pause", "pause.circle") {
                    await act("paused") { try await apiClient.pauseMigration(id: job.id) }
                }
            }
            if status == "paused" {
                actionButton("Resume", "play.circle") {
                    await act("resumed") { try await apiClient.resumeMigration(id: job.id) }
                }
            }
            if status != "completed" && status != "cancelled" && status != "canceled" && status != "failed" {
                Button(role: .destructive) {
                    pendingCancel = true
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .disabled(isMutating)
            }
        }
    }

    private func actionButton(_ title: String, _ icon: String, _ run: @escaping () async -> Void) -> some View {
        Button {
            Task { await run() }
        } label: {
            Label(title, systemImage: icon)
        }
        .disabled(isMutating)
    }

    private func loadDetail() async {
        do {
            fetched = try await apiClient.getMigration(id: listJob.id)
            loadError = nil
        } catch {
            loadError = "Showing cached details; could not refresh: \(error.localizedDescription)"
        }
    }

    private func act(_ verb: String, _ run: () async throws -> MigrationJob) async {
        isMutating = true
        defer { isMutating = false }
        do {
            fetched = try await run()
            actionMessage = (true, "Migration \(verb).")
        } catch {
            actionMessage = (false, "Action failed: \(error.localizedDescription)")
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

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

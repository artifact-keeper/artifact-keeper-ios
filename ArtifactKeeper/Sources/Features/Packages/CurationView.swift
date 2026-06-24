import SwiftUI

/// Package curation review for a staging repository. The operator enters a
/// staging repository id, then sees the curation stats
/// (GET /api/v1/curation/stats) and the packages awaiting review
/// (GET /api/v1/curation/packages), and can approve or block each
/// (POST .../approve | .../block).
struct CurationView: View {
    @State private var stagingRepoId = ""
    @State private var activeRepoId: String?
    @State private var stats: CurationStats?
    @State private var packages: [CurationPackage] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var mutatingId: String?
    @State private var actionMessage: (success: Bool, text: String)?

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Staging repository id", text: $stagingRepoId)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
                    .onSubmit { Task { await load() } }
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(stagingRepoId.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading curation\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Curation Unavailable", systemImage: "checklist")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.borderedProminent)
            }
        } else if !hasSearched {
            ContentUnavailableView(
                "Review Curation",
                systemImage: "checklist",
                description: Text("Enter a staging repository id to review its packages.")
            )
        } else {
            List {
                if let actionMessage {
                    Section {
                        Label(actionMessage.text, systemImage: actionMessage.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(actionMessage.success ? .green : .red)
                    }
                }

                if let stats, !stats.counts.isEmpty {
                    Section("Stats") {
                        ForEach(stats.counts) { count in
                            HStack {
                                Text(count.status.capitalized).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(count.count)").font(.subheadline.weight(.semibold))
                            }
                            .font(.subheadline)
                        }
                    }
                }

                Section("Packages") {
                    if packages.isEmpty {
                        Text("No packages awaiting curation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(packages) { pkg in
                            CurationPackageRow(
                                package: pkg,
                                isMutating: mutatingId == pkg.id,
                                onApprove: { await act(pkg, approve: true) },
                                onBlock: { await act(pkg, approve: false) }
                            )
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func load() async {
        let trimmed = stagingRepoId.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        activeRepoId = trimmed
        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }
        do {
            async let statsResult = apiClient.getCurationStats(stagingRepoId: trimmed)
            async let packagesResult = apiClient.listCurationPackages(stagingRepoId: trimmed)
            stats = try? await statsResult
            packages = try await packagesResult
        } catch {
            packages = []
            stats = nil
            errorMessage = "Could not load curation for that staging repository: \(error.localizedDescription)"
        }
    }

    private func act(_ pkg: CurationPackage, approve: Bool) async {
        mutatingId = pkg.id
        defer { mutatingId = nil }
        do {
            if approve {
                _ = try await apiClient.approveCurationPackage(id: pkg.id)
                actionMessage = (true, "Approved \(pkg.name) \(pkg.version).")
            } else {
                _ = try await apiClient.blockCurationPackage(id: pkg.id)
                actionMessage = (true, "Blocked \(pkg.name) \(pkg.version).")
            }
            await load()
        } catch {
            actionMessage = (false, "Action failed for \(pkg.name): \(error.localizedDescription)")
        }
    }
}

private struct CurationPackageRow: View {
    let package: CurationPackage
    let isMutating: Bool
    let onApprove: () async -> Void
    let onBlock: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(package.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(package.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(package.format)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }
            Text("\(package.repositoryKey) \u{00B7} \(byteString(package.sizeBytes))")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    Task { await onApprove() }
                } label: {
                    Label("Approve", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .tint(.green)
                .disabled(isMutating)

                Button(role: .destructive) {
                    Task { await onBlock() }
                } label: {
                    Label("Block", systemImage: "hand.raised")
                }
                .buttonStyle(.borderless)
                .disabled(isMutating)

                if isMutating {
                    ProgressView().controlSize(.small)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

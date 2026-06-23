import SwiftUI

// The Artifact Detail screen for the 1.2.1 artifact endpoints. Fetches full
// detail, format metadata, download stats and labels, and lets the user add or
// remove labels. Presented as a sheet from the repository artifact list.
struct ArtifactDetailView: View {
    let repoKey: String

    @StateObject private var viewModel: ArtifactDetailView.Model
    @Environment(\.dismiss) private var dismiss

    @State private var showAddLabel = false
    @State private var labelToDelete: ArtifactLabel?

    typealias Model = ArtifactDetailViewModel

    init(artifactId: String, repoKey: String, api: APIClient = .shared) {
        self.repoKey = repoKey
        _viewModel = StateObject(wrappedValue: ArtifactDetailViewModel(artifactId: artifactId, api: api))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Artifact")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .task { await viewModel.load() }
                .sheet(isPresented: $showAddLabel) {
                    AddLabelSheet { key, value in
                        await viewModel.addLabel(key: key, value: value)
                    }
                }
                .alert(
                    "Remove Label?",
                    isPresented: Binding(
                        get: { labelToDelete != nil },
                        set: { if !$0 { labelToDelete = nil } }
                    )
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove", role: .destructive) {
                        if let label = labelToDelete {
                            Task { await viewModel.deleteLabel(key: label.key) }
                        }
                    }
                } message: {
                    Text("This removes the label from the artifact.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.detail == nil {
            ProgressView("Loading artifact\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.detail == nil {
            ContentUnavailableView {
                Label("Could Not Load Artifact", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        } else if let detail = viewModel.detail {
            List {
                infoSection(detail)
                checksumSection(detail)
                if let stats = viewModel.stats { statsSection(stats) }
                if let metadata = viewModel.metadata { metadataSection(metadata) }
                labelsSection
                downloadSection(detail)
            }
            .refreshable { await viewModel.load() }
        } else {
            ContentUnavailableView("No Artifact", systemImage: "shippingbox")
        }
    }

    // Simple download affordance: opens the artifact's download URL in the system
    // browser. No streaming/download-manager infra; the heavier upload/chunked
    // flows are deferred to a later wave.
    private func downloadSection(_ detail: ArtifactDetail) -> some View {
        Section {
            Button {
                Task { await openDownload(detail) }
            } label: {
                Label("Download in Browser", systemImage: "arrow.down.circle")
            }
        }
    }

    private func openDownload(_ detail: ArtifactDetail) async {
        guard let url = await viewModel.downloadURL(repoKey: repoKey, path: detail.path) else { return }
        #if os(iOS)
        await UIApplication.shared.open(url)
        #elseif os(macOS)
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
        #endif
    }

    private func infoSection(_ detail: ArtifactDetail) -> some View {
        Section("Artifact") {
            LabeledContent("Name", value: detail.name)
            LabeledContent("Path", value: detail.path)
            if let version = detail.version, !version.isEmpty {
                LabeledContent("Version", value: version)
            }
            LabeledContent("Repository", value: detail.repositoryKey)
            LabeledContent("Content Type", value: detail.contentType)
            LabeledContent("Size", value: Self.formatBytes(detail.sizeBytes))
            LabeledContent("Downloads", value: "\(detail.downloadCount)")
            LabeledContent("Created", value: detail.createdAt)
        }
    }

    @ViewBuilder
    private func checksumSection(_ detail: ArtifactDetail) -> some View {
        if !detail.checksumSha256.isEmpty {
            Section("Checksum") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHA-256").font(.caption).foregroundStyle(.secondary)
                    Text(detail.checksumSha256)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func statsSection(_ stats: ArtifactStats) -> some View {
        Section("Download Stats") {
            LabeledContent("Total Downloads", value: "\(stats.downloadCount)")
            if let first = stats.firstDownloaded {
                LabeledContent("First Download", value: first)
            }
            if let last = stats.lastDownloaded {
                LabeledContent("Last Download", value: last)
            }
        }
    }

    @ViewBuilder
    private func metadataSection(_ metadata: ArtifactMetadata) -> some View {
        Section("Metadata") {
            LabeledContent("Format", value: metadata.format)
            ForEach(Self.sortedPairs(metadata.metadata), id: \.0) { pair in
                LabeledContent(pair.0, value: pair.1)
            }
        }
        let properties = Self.sortedPairs(metadata.properties)
        if !properties.isEmpty {
            Section("Properties") {
                ForEach(properties, id: \.0) { pair in
                    LabeledContent(pair.0, value: pair.1)
                }
            }
        }
    }

    private var labelsSection: some View {
        Section {
            if viewModel.labels.isEmpty {
                Text("No labels")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.labels) { label in
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        Text(label.key).fontWeight(.medium)
                        Spacer()
                        Text(label.value).foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            labelToDelete = label
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            if let labelError = viewModel.labelError {
                Text(labelError).font(.caption).foregroundStyle(.red)
            }
        } header: {
            HStack {
                Text("Labels")
                Spacer()
                Button {
                    showAddLabel = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .disabled(viewModel.isMutatingLabels)
            }
        }
    }

    // MARK: - Helpers

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func sortedPairs(_ map: [String: JSONValue]?) -> [(String, String)] {
        guard let map else { return [] }
        return map.map { ($0.key, $0.value.displayString) }.sorted { $0.0 < $1.0 }
    }
}

// MARK: - Add Label Sheet

private struct AddLabelSheet: View {
    let onAdd: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var value = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Key", text: $key)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Value", text: $value)
                        .autocorrectionDisabled()
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Label")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            await onAdd(key, value)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving { ProgressView().controlSize(.small) } else { Text("Add") }
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 220)
    }
}

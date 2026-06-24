import SwiftUI

/// Repository label editor (/api/v1/repositories/{key}/labels). Lists labels and
/// supports adding a key/value and deleting a label.
struct RepoLabelsView: View {
    let repoKey: String

    @State private var labels: [RepoLabel] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isMutating = false

    @State private var showAdd = false
    @State private var labelToDelete: RepoLabel?

    private let apiClient = APIClient.shared

    var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if labels.isEmpty {
                    ContentUnavailableView(
                        "No Labels",
                        systemImage: "tag",
                        description: Text("Add labels to organize and filter this repository.")
                    )
                } else {
                    ForEach(labels) { label in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label.key).font(.subheadline.weight(.medium))
                                Text(label.value)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                labelToDelete = label
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isMutating)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } header: {
                HStack {
                    Text("Labels")
                    Spacer()
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AddRepoLabelView(repoKey: repoKey) { await load() }
            }
        }
        .confirmationDialog(
            "Delete label \(labelToDelete?.key ?? "")?",
            isPresented: Binding(
                get: { labelToDelete != nil },
                set: { if !$0 { labelToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let label = labelToDelete {
                    Task { await delete(label) }
                }
            }
            Button("Cancel", role: .cancel) { labelToDelete = nil }
        }
    }

    private func load() async {
        isLoading = labels.isEmpty
        do {
            labels = try await apiClient.listRepoLabels(repoKey: repoKey)
                .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            errorMessage = nil
        } catch {
            if labels.isEmpty {
                errorMessage = "Could not load labels. You may need admin privileges."
            }
        }
        isLoading = false
    }

    private func delete(_ label: RepoLabel) async {
        isMutating = true
        defer { isMutating = false; labelToDelete = nil }
        do {
            try await apiClient.deleteRepoLabel(repoKey: repoKey, key: label.key)
            await load()
        } catch {
            errorMessage = "Failed to delete \(label.key): \(error.localizedDescription)"
        }
    }
}

/// Add-label sheet: key + value.
private struct AddRepoLabelView: View {
    let repoKey: String
    let onAdded: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var value = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Form {
            Section("Label") {
                TextField("Key", text: $key)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
                TextField("Value", text: $value)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Add Label")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { Task { await add() } }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
    }

    private func add() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        do {
            _ = try await apiClient.addRepoLabel(
                repoKey: repoKey,
                key: trimmedKey,
                value: trimmedValue.isEmpty ? nil : trimmedValue
            )
            await onAdded()
            dismiss()
        } catch {
            errorMessage = "Could not add label: \(error.localizedDescription)"
        }
    }
}

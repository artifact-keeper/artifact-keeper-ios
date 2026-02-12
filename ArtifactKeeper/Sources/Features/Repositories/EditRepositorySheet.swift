import SwiftUI

struct EditRepositorySheet: View {
    let repository: Repository
    let onUpdated: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var key: String
    @State private var name: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    private var originalKey: String

    private var keyChanged: Bool {
        key != originalKey
    }

    private var isValid: Bool {
        !key.isEmpty && !name.isEmpty
    }

    init(repository: Repository, onUpdated: @escaping (String) -> Void) {
        self.repository = repository
        self.onUpdated = onUpdated
        self.originalKey = repository.key
        _key = State(initialValue: repository.key)
        _name = State(initialValue: repository.name)
        _description = State(initialValue: repository.description ?? "")
        _isPublic = State(initialValue: repository.isPublic)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key", text: $key)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: key) { _, newValue in
                            key = newValue.lowercased()
                        }
                    TextField("Name", text: $name)
                } header: {
                    Text("Basic Info")
                }

                if keyChanged {
                    Section {
                        Label(
                            "Changing the repository key will update all URLs and client configurations. Existing integrations using the old key will break.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.callout)
                        .foregroundStyle(.orange)
                    }
                }

                Section("Options") {
                    Toggle("Public", isOn: $isPublic)
                    TextField("Description (optional)", text: $description)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Repository")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRepository()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
        }
    }

    private func saveRepository() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let request = UpdateRepositoryRequest(
                    key: keyChanged ? key : nil,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    isPublic: isPublic
                )

                _ = try await apiClient.updateRepository(key: originalKey, request: request)

                dismiss()
                onUpdated(key)
            } catch {
                errorMessage = error.localizedDescription
            }

            isSaving = false
        }
    }
}

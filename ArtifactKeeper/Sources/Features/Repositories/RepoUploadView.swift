import SwiftUI
import UniformTypeIdentifiers

struct RepoUploadView: View {
    let repoKey: String
    var onUploadComplete: (() -> Void)?

    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var customPath = ""
    @State private var isUploading = false
    @State private var resultMessage: (success: Bool, text: String)?

    private let apiClient = APIClient.shared

    var body: some View {
        Form {
            Section("File") {
                HStack {
                    if let url = selectedFileURL {
                        Label(url.lastPathComponent, systemImage: "doc.fill")
                            .lineLimit(1)
                    } else {
                        Text("No file selected")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose File\u{2026}") {
                        showingFilePicker = true
                    }
                }
            }

            Section {
                TextField("Custom path (optional)", text: $customPath)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text("Destination Path")
            } footer: {
                Text("Leave blank to use the file name as the artifact path")
            }

            if let result = resultMessage {
                Section {
                    Label(result.text, systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                }
            }

            Section {
                Button {
                    Task { await uploadFile() }
                } label: {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isUploading ? "Uploading\u{2026}" : "Upload")
                    }
                }
                .disabled(selectedFileURL == nil || isUploading)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item],
            onCompletion: { result in
                if case .success(let url) = result {
                    selectedFileURL = url
                    resultMessage = nil
                }
            }
        )
    }

    private func uploadFile() async {
        guard let fileURL = selectedFileURL else { return }
        isUploading = true
        resultMessage = nil

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        do {
            let artifact = try await apiClient.uploadArtifact(
                repoKey: repoKey,
                fileURL: fileURL,
                customPath: customPath.isEmpty ? nil : customPath
            )
            resultMessage = (true, "Uploaded \(artifact.name) successfully")
            selectedFileURL = nil
            customPath = ""
            onUploadComplete?()
        } catch {
            resultMessage = (false, error.localizedDescription)
        }

        isUploading = false
    }
}

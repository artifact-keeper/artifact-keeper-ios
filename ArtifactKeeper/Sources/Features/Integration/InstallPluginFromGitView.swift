import SwiftUI

/// Sheet for installing a format plugin from a Git repository
/// (POST /api/v1/plugins/install/git). The operator enters a repository URL and
/// an optional ref (tag, branch, or commit).
struct InstallPluginFromGitView: View {
    /// Called with the install result after a successful install so the caller
    /// can refresh its list and surface a confirmation.
    let onInstalled: (PluginInstallResult) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var ref = ""
    @State private var isInstalling = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Repository") {
                TextField("Git URL (https://...)", text: $url)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .disableAutocorrection(true)
                    #endif
                TextField("Ref (optional: tag, branch, or commit)", text: $ref)
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

            Section {
                Button {
                    Task { await install() }
                } label: {
                    if isInstalling {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Installing\u{2026}")
                        }
                    } else {
                        Text("Install")
                    }
                }
                .disabled(trimmedURL.isEmpty || isInstalling)
            }
        }
        .navigationTitle("Install from Git")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isInstalling)
            }
        }
    }

    private func install() async {
        isInstalling = true
        errorMessage = nil
        defer { isInstalling = false }
        let trimmedRef = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await apiClient.installPluginFromGit(
                url: trimmedURL,
                ref: trimmedRef.isEmpty ? nil : trimmedRef
            )
            await onInstalled(result)
            dismiss()
        } catch {
            errorMessage = "Install failed: \(error.localizedDescription)"
        }
    }
}

import SwiftUI

struct RepoSecurityConfigView: View {
    let repoKey: String

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveSuccess = false
    @State private var hasLoaded = false

    @State private var scanEnabled = false
    @State private var scanOnUpload = true
    @State private var scanOnProxy = false
    @State private var blockOnPolicyViolation = false
    @State private var severityThreshold = "high"

    private let apiClient = APIClient.shared
    private let thresholds = ["critical", "high", "medium", "low"]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading security config\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, !hasLoaded {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                configForm
            }
        }
        .task { await loadConfig() }
    }

    private var configForm: some View {
        Form {
            Section("Scanning") {
                Toggle("Enable Scanning", isOn: $scanEnabled)
                Toggle("Scan on Upload", isOn: $scanOnUpload)
                    .disabled(!scanEnabled)
                Toggle("Scan on Proxy", isOn: $scanOnProxy)
                    .disabled(!scanEnabled)
            }

            Section("Policy") {
                Toggle("Block on Policy Violation", isOn: $blockOnPolicyViolation)
                Picker("Severity Threshold", selection: $severityThreshold) {
                    ForEach(thresholds, id: \.self) { t in
                        Text(t.capitalized).tag(t)
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if saveSuccess {
                Section {
                    Label("Settings saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button {
                    Task { await saveConfig() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSaving ? "Saving\u{2026}" : "Save")
                    }
                }
                .disabled(isSaving)
            }
        }
        .formStyle(.grouped)
    }

    private func loadConfig() async {
        isLoading = true
        errorMessage = nil

        do {
            let config = try await apiClient.getRepoSecurityConfig(repoKey: repoKey)
            scanEnabled = config.scanEnabled
            scanOnUpload = config.scanOnUpload
            scanOnProxy = config.scanOnProxy
            blockOnPolicyViolation = config.blockOnPolicyViolation
            severityThreshold = config.severityThreshold
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveConfig() async {
        isSaving = true
        errorMessage = nil
        saveSuccess = false

        let config = RepoSecurityConfig(
            scanEnabled: scanEnabled,
            scanOnUpload: scanOnUpload,
            scanOnProxy: scanOnProxy,
            blockOnPolicyViolation: blockOnPolicyViolation,
            severityThreshold: severityThreshold
        )

        do {
            _ = try await apiClient.updateRepoSecurityConfig(repoKey: repoKey, config: config)
            saveSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

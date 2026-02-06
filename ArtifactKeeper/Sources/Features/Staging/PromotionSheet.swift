import SwiftUI

struct PromotionSheet: View {
    let repo: StagingRepository
    let artifacts: [StagingArtifact]
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targetRepoKey: String = ""
    @State private var comment: String = ""
    @State private var forcePromotion = false
    @State private var isPromoting = false
    @State private var promotionResult: PromotionResultState?
    @State private var errorMessage: String?
    @State private var showingConfirmation = false

    private let apiClient = APIClient.shared

    var isBulkPromotion: Bool {
        artifacts.count > 1
    }

    var hasFailingArtifacts: Bool {
        artifacts.contains { $0.policyStatus.lowercased() != "passing" }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if isBulkPromotion {
                            Label("\(artifacts.count) artifacts selected", systemImage: "doc.on.doc.fill")
                                .font(.headline)
                        } else if let artifact = artifacts.first {
                            HStack(spacing: 12) {
                                Image(systemName: statusIcon(for: artifact))
                                    .font(.title2)
                                    .foregroundStyle(statusColor(for: artifact))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artifact.name)
                                        .font(.headline)
                                    if let version = artifact.version {
                                        Text("Version \(version)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Artifact\(isBulkPromotion ? "s" : "")")
                }

                Section {
                    TextField("Target Repository Key", text: $targetRepoKey)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    if let defaultTarget = repo.targetRepoKey, !defaultTarget.isEmpty {
                        Button {
                            targetRepoKey = defaultTarget
                        } label: {
                            HStack {
                                Text("Use default: ")
                                    .foregroundStyle(.secondary)
                                Text(defaultTarget)
                                    .foregroundStyle(.blue)
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Destination")
                } footer: {
                    Text("The repository where the artifact(s) will be promoted to.")
                }

                Section {
                    TextField("Optional comment", text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Comment")
                }

                if hasFailingArtifacts {
                    Section {
                        Toggle("Force promotion", isOn: $forcePromotion)
                    } header: {
                        Text("Options")
                    } footer: {
                        Label("Force promotion bypasses policy checks. Use with caution.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let result = promotionResult {
                    Section {
                        PromotionResultView(result: result)
                    } header: {
                        Text("Result")
                    }
                }
            }
            .navigationTitle(isBulkPromotion ? "Bulk Promotion" : "Promote Artifact")
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
                    if promotionResult != nil {
                        Button("Done") {
                            dismiss()
                        }
                    } else {
                        Button {
                            if hasFailingArtifacts && !forcePromotion {
                                showingConfirmation = true
                            } else {
                                Task { await promote() }
                            }
                        } label: {
                            if isPromoting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Promote")
                            }
                        }
                        .disabled(targetRepoKey.isEmpty || isPromoting)
                    }
                }
            }
            .alert("Promote Artifacts?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Promote Anyway") {
                    forcePromotion = true
                    Task { await promote() }
                }
            } message: {
                Text("Some artifacts have policy violations. Force promotion will bypass these checks.")
            }
        }
    }

    private func statusIcon(for artifact: StagingArtifact) -> String {
        switch artifact.policyStatus.lowercased() {
        case "passing": return "checkmark.circle.fill"
        case "failing": return "xmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "clock.fill"
        }
    }

    private func statusColor(for artifact: StagingArtifact) -> Color {
        switch artifact.policyStatus.lowercased() {
        case "passing": return .green
        case "failing": return .red
        case "warning": return .yellow
        default: return .gray
        }
    }

    private func promote() async {
        isPromoting = true
        errorMessage = nil

        do {
            if isBulkPromotion {
                let request = BulkPromotionRequest(
                    artifactIds: artifacts.map { $0.id },
                    targetRepoKey: targetRepoKey,
                    force: forcePromotion ? true : nil,
                    comment: comment.isEmpty ? nil : comment
                )
                let response = try await apiClient.promoteBulk(repoKey: repo.key, request: request)
                promotionResult = .bulk(response)
            } else if let artifact = artifacts.first {
                let request = PromotionRequest(
                    targetRepoKey: targetRepoKey,
                    force: forcePromotion ? true : nil,
                    comment: comment.isEmpty ? nil : comment
                )
                let response = try await apiClient.promoteArtifact(
                    repoKey: repo.key,
                    artifactId: artifact.id,
                    request: request
                )
                promotionResult = .single(response)
            }
            await onComplete()
        } catch {
            errorMessage = "Promotion failed: \(error.localizedDescription)"
        }

        isPromoting = false
    }
}

// MARK: - Promotion Result State

enum PromotionResultState {
    case single(PromotionResponse)
    case bulk(BulkPromotionResponse)
}

// MARK: - Promotion Result View

struct PromotionResultView: View {
    let result: PromotionResultState

    var body: some View {
        switch result {
        case .single(let response):
            SinglePromotionResultView(response: response)

        case .bulk(let response):
            BulkPromotionResultView(response: response)
        }
    }
}

struct SinglePromotionResultView: View {
    let response: PromotionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: response.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(response.success ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    Text(response.success ? "Promotion Successful" : "Promotion Failed")
                        .font(.headline)

                    if let message = response.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let path = response.promotedPath {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Promoted to:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let warnings = response.warnings, !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warnings:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption2)
                            Text(warning)
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct BulkPromotionResultView: View {
    let response: BulkPromotionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary
            HStack(spacing: 16) {
                VStack {
                    Text("\(response.totalSucceeded)")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("Succeeded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(response.totalFailed)")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                    Text("Failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(response.totalRequested)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            // Individual results
            if !response.results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(response.results, id: \.artifactId) { result in
                        HStack(spacing: 8) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.success ? .green : .red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.artifactId)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)

                                if let message = result.message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

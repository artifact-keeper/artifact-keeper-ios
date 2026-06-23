import Foundation
import SwiftUI

// Drives the Artifact Detail screen against the 1.2.1 artifact endpoints:
// detail, metadata, stats, and the artifact-labels CRUD. Loads run concurrently
// and degrade independently so a failure in one section does not blank the screen.
@MainActor
final class ArtifactDetailViewModel: ObservableObject {
    @Published var detail: ArtifactDetail?
    @Published var metadata: ArtifactMetadata?
    @Published var stats: ArtifactStats?
    @Published var labels: [ArtifactLabel] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var labelError: String?
    @Published var isMutatingLabels = false

    let artifactId: String
    private let api: APIClient

    init(artifactId: String, api: APIClient = .shared) {
        self.artifactId = artifactId
        self.api = api
    }

    /// Load detail, metadata, stats and labels. The core detail call drives the
    /// top-level error state; metadata/stats/labels are best-effort so a partial
    /// backend still renders a useful screen.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await api.getArtifactDetail(id: artifactId)
        } catch {
            errorMessage = Self.message(from: error)
            isLoading = false
            return
        }

        async let metadataResult = try? api.getArtifactMetadata(id: artifactId)
        async let statsResult = try? api.getArtifactStats(id: artifactId)
        async let labelsResult = try? api.listArtifactLabels(id: artifactId)

        metadata = await metadataResult
        stats = await statsResult
        labels = await labelsResult ?? []

        isLoading = false
    }

    /// Build the browser download URL for this artifact's path. Returns nil when
    /// no server is configured.
    func downloadURL(repoKey: String, path: String) async -> URL? {
        await api.buildDownloadURL(repoKey: repoKey, artifactPath: path)
    }

    /// Reload only the label set, used after add/delete.
    func reloadLabels() async {
        labels = (try? await api.listArtifactLabels(id: artifactId)) ?? labels
    }

    func addLabel(key: String, value: String) async {
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return }
        isMutatingLabels = true
        labelError = nil
        defer { isMutatingLabels = false }
        do {
            let trimmedValue = value.trimmingCharacters(in: .whitespaces)
            _ = try await api.addArtifactLabel(
                id: artifactId,
                key: trimmedKey,
                value: trimmedValue.isEmpty ? nil : trimmedValue
            )
            await reloadLabels()
        } catch {
            labelError = Self.message(from: error)
        }
    }

    func deleteLabel(key: String) async {
        isMutatingLabels = true
        labelError = nil
        defer { isMutatingLabels = false }
        do {
            try await api.deleteArtifactLabel(id: artifactId, key: key)
            await reloadLabels()
        } catch {
            labelError = Self.message(from: error)
        }
    }

    private static func message(from error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return error.localizedDescription
    }
}

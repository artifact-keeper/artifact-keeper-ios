import Foundation

// MARK: - Curation (1.2.1 /api/v1/curation/*)

/// A package awaiting curation review in a staging repository
/// (GET /api/v1/curation/packages). Approve/block return the same shape.
struct CurationPackage: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let repositoryKey: String
    let name: String
    let version: String
    let format: String
    let description: String?
    let sizeBytes: Int64
    let downloadCount: Int64
    let createdAt: String
    let updatedAt: String
}

/// One status bucket in the curation stats (e.g. pending: 12).
struct CurationStatusCount: Codable, Identifiable, Sendable, Equatable {
    let status: String
    let count: Int64

    var id: String { status }
}

/// Curation stats for a staging repository (GET /api/v1/curation/stats).
struct CurationStats: Sendable, Equatable {
    let stagingRepoId: String
    let counts: [CurationStatusCount]
}

/// Body for the bulk approve/block endpoints.
struct BulkStatusRequest: Encodable {
    let ids: [String]
    let reason: String
}

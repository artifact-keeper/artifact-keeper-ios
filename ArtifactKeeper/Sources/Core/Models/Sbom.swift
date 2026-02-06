import Foundation

// MARK: - SBOM Types

enum SbomFormat: String, Codable, CaseIterable, Sendable {
    case cyclonedx
    case spdx

    var displayName: String {
        switch self {
        case .cyclonedx: return "CycloneDX"
        case .spdx: return "SPDX"
        }
    }
}

enum PolicyAction: String, Codable, CaseIterable, Sendable {
    case allow
    case warn
    case block

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .allow: return "green"
        case .warn: return "yellow"
        case .block: return "red"
        }
    }
}

enum CveStatus: String, Codable, Sendable {
    case open
    case fixed
    case acknowledged
    case falsePositive = "false_positive"
}

// MARK: - SBOM Document

struct SbomResponse: Codable, Identifiable, Sendable {
    let id: String
    let artifactId: String
    let repositoryId: String
    let format: String
    let formatVersion: String
    let specVersion: String?
    let componentCount: Int
    let dependencyCount: Int
    let licenseCount: Int
    let licenses: [String]
    let contentHash: String
    let generator: String?
    let generatorVersion: String?
    let generatedAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, format, licenses, generator
        case artifactId = "artifact_id"
        case repositoryId = "repository_id"
        case formatVersion = "format_version"
        case specVersion = "spec_version"
        case componentCount = "component_count"
        case dependencyCount = "dependency_count"
        case licenseCount = "license_count"
        case contentHash = "content_hash"
        case generatorVersion = "generator_version"
        case generatedAt = "generated_at"
        case createdAt = "created_at"
    }
}

struct SbomContentResponse: Codable, Identifiable, Sendable {
    let id: String
    let artifactId: String
    let repositoryId: String
    let format: String
    let formatVersion: String
    let specVersion: String?
    let componentCount: Int
    let dependencyCount: Int
    let licenseCount: Int
    let licenses: [String]
    let contentHash: String
    let generator: String?
    let generatorVersion: String?
    let generatedAt: String
    let createdAt: String
    let content: AnyCodable

    enum CodingKeys: String, CodingKey {
        case id, format, licenses, generator, content
        case artifactId = "artifact_id"
        case repositoryId = "repository_id"
        case formatVersion = "format_version"
        case specVersion = "spec_version"
        case componentCount = "component_count"
        case dependencyCount = "dependency_count"
        case licenseCount = "license_count"
        case contentHash = "content_hash"
        case generatorVersion = "generator_version"
        case generatedAt = "generated_at"
        case createdAt = "created_at"
    }
}

struct SbomComponent: Codable, Identifiable, Sendable {
    let id: String
    let sbomId: String
    let name: String
    let version: String?
    let purl: String?
    let cpe: String?
    let componentType: String?
    let licenses: [String]
    let sha256: String?
    let sha1: String?
    let md5: String?
    let supplier: String?
    let author: String?

    enum CodingKeys: String, CodingKey {
        case id, name, version, purl, cpe, licenses, sha256, sha1, md5, supplier, author
        case sbomId = "sbom_id"
        case componentType = "component_type"
    }
}

// MARK: - CVE History

struct CveHistoryEntry: Codable, Identifiable, Sendable {
    let id: String
    let artifactId: String
    let sbomId: String?
    let componentId: String?
    let scanResultId: String?
    let cveId: String
    let affectedComponent: String?
    let affectedVersion: String?
    let fixedVersion: String?
    let severity: String?
    let cvssScore: Double?
    let cvePublishedAt: String?
    let firstDetectedAt: String
    let lastDetectedAt: String
    let status: String
    let acknowledgedBy: String?
    let acknowledgedAt: String?
    let acknowledgedReason: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, severity, status
        case artifactId = "artifact_id"
        case sbomId = "sbom_id"
        case componentId = "component_id"
        case scanResultId = "scan_result_id"
        case cveId = "cve_id"
        case affectedComponent = "affected_component"
        case affectedVersion = "affected_version"
        case fixedVersion = "fixed_version"
        case cvssScore = "cvss_score"
        case cvePublishedAt = "cve_published_at"
        case firstDetectedAt = "first_detected_at"
        case lastDetectedAt = "last_detected_at"
        case acknowledgedBy = "acknowledged_by"
        case acknowledgedAt = "acknowledged_at"
        case acknowledgedReason = "acknowledged_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CveTrends: Codable, Sendable {
    let totalCves: Int
    let openCves: Int
    let fixedCves: Int
    let acknowledgedCves: Int
    let criticalCount: Int
    let highCount: Int
    let mediumCount: Int
    let lowCount: Int
    let avgDaysToFix: Double?

    enum CodingKeys: String, CodingKey {
        case totalCves = "total_cves"
        case openCves = "open_cves"
        case fixedCves = "fixed_cves"
        case acknowledgedCves = "acknowledged_cves"
        case criticalCount = "critical_count"
        case highCount = "high_count"
        case mediumCount = "medium_count"
        case lowCount = "low_count"
        case avgDaysToFix = "avg_days_to_fix"
    }
}

// MARK: - License Policy

struct LicensePolicy: Codable, Identifiable, Sendable {
    let id: String
    let repositoryId: String?
    let name: String
    let description: String?
    let allowedLicenses: [String]
    let deniedLicenses: [String]
    let allowUnknown: Bool
    let action: String
    let isEnabled: Bool
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, action
        case repositoryId = "repository_id"
        case allowedLicenses = "allowed_licenses"
        case deniedLicenses = "denied_licenses"
        case allowUnknown = "allow_unknown"
        case isEnabled = "is_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LicenseCheckResult: Codable, Sendable {
    let compliant: Bool
    let action: String
    let violations: [LicenseViolation]
    let warnings: [String]
}

struct LicenseViolation: Codable, Sendable {
    let license: String
    let reason: String
}

// MARK: - Request Types

struct GenerateSbomRequest: Encodable {
    let artifactId: String
    let format: String
    let forceRegenerate: Bool

    enum CodingKeys: String, CodingKey {
        case artifactId = "artifact_id"
        case format
        case forceRegenerate = "force_regenerate"
    }
}

struct CreateLicensePolicyRequest: Encodable {
    let repositoryId: String?
    let name: String
    let description: String?
    let allowedLicenses: [String]
    let deniedLicenses: [String]
    let allowUnknown: Bool
    let action: String
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case name, description, action
        case repositoryId = "repository_id"
        case allowedLicenses = "allowed_licenses"
        case deniedLicenses = "denied_licenses"
        case allowUnknown = "allow_unknown"
        case isEnabled = "is_enabled"
    }
}

// MARK: - AnyCodable helper for dynamic JSON

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Failed to decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Failed to encode AnyCodable"))
        }
    }
}

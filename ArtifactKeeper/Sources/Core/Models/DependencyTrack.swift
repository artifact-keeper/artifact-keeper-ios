import Foundation

// MARK: - Status

struct DtStatus: Codable, Sendable {
    let enabled: Bool
    let healthy: Bool
    let url: String?
}

// MARK: - Projects

struct DtProject: Codable, Identifiable, Hashable, Sendable {
    let uuid: String
    let name: String
    let version: String?
    let description: String?
    let lastBomImport: Int64?
    let lastBomImportFormat: String?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, version, description
        case lastBomImport = "lastBomImport"
        case lastBomImportFormat = "lastBomImportFormat"
    }
}

// MARK: - Components

struct DtComponent: Codable, Sendable {
    let uuid: String
    let name: String
    let version: String?
    let group: String?
    let purl: String?
}

struct DtComponentFull: Codable, Identifiable, Sendable {
    let uuid: String
    let name: String
    let version: String?
    let group: String?
    let purl: String?
    let cpe: String?
    let resolvedLicense: DtLicense?
    let isInternal: Bool?

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, version, group, purl, cpe
        case resolvedLicense = "resolvedLicense"
        case isInternal = "isInternal"
    }
}

struct DtLicense: Codable, Sendable {
    let uuid: String?
    let licenseId: String?
    let name: String

    enum CodingKeys: String, CodingKey {
        case uuid, name
        case licenseId = "licenseId"
    }
}

// MARK: - Vulnerabilities

struct DtVulnerability: Codable, Sendable {
    let uuid: String
    let vulnId: String
    let source: String
    let severity: String
    let title: String?
    let description: String?
    let cvssV3BaseScore: Double?
    let cwe: DtCwe?

    enum CodingKeys: String, CodingKey {
        case uuid, source, severity, title, description, cwe
        case vulnId = "vulnId"
        case cvssV3BaseScore = "cvssV3BaseScore"
    }
}

struct DtCwe: Codable, Sendable {
    let cweId: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case cweId = "cweId"
        case name
    }
}

// MARK: - Analysis

struct DtAnalysis: Codable, Sendable {
    let state: String?
    let justification: String?
    let response: String?
    let details: String?
    let isSuppressed: Bool

    enum CodingKeys: String, CodingKey {
        case state, justification, response, details
        case isSuppressed = "isSuppressed"
    }
}

struct DtAnalysisResponse: Codable, Sendable {
    let analysisState: String
    let analysisJustification: String?
    let analysisDetails: String?
    let isSuppressed: Bool

    enum CodingKeys: String, CodingKey {
        case analysisState = "analysisState"
        case analysisJustification = "analysisJustification"
        case analysisDetails = "analysisDetails"
        case isSuppressed = "isSuppressed"
    }
}

// MARK: - Attribution

struct DtAttribution: Codable, Sendable {
    let analyzerIdentity: String?
    let attributedOn: Int64?

    enum CodingKeys: String, CodingKey {
        case analyzerIdentity = "analyzerIdentity"
        case attributedOn = "attributedOn"
    }
}

// MARK: - Findings

struct DtFinding: Codable, Identifiable, Sendable {
    let component: DtComponent
    let vulnerability: DtVulnerability
    let analysis: DtAnalysis?
    let attribution: DtAttribution?

    var id: String { "\(component.uuid)-\(vulnerability.uuid)" }
}

// MARK: - Metrics

struct DtProjectMetrics: Codable, Sendable {
    let critical: Int64
    let high: Int64
    let medium: Int64
    let low: Int64
    let unassigned: Int64
    let vulnerabilities: Int64?
    let findingsTotal: Int64
    let findingsAudited: Int64
    let findingsUnaudited: Int64
    let suppressions: Int64
    let inheritedRiskScore: Double
    let policyViolationsFail: Int64
    let policyViolationsWarn: Int64
    let policyViolationsInfo: Int64
    let policyViolationsTotal: Int64
    let firstOccurrence: Int64?
    let lastOccurrence: Int64?

    enum CodingKeys: String, CodingKey {
        case critical, high, medium, low, unassigned, vulnerabilities, suppressions
        case findingsTotal = "findingsTotal"
        case findingsAudited = "findingsAudited"
        case findingsUnaudited = "findingsUnaudited"
        case inheritedRiskScore = "inheritedRiskScore"
        case policyViolationsFail = "policyViolationsFail"
        case policyViolationsWarn = "policyViolationsWarn"
        case policyViolationsInfo = "policyViolationsInfo"
        case policyViolationsTotal = "policyViolationsTotal"
        case firstOccurrence = "firstOccurrence"
        case lastOccurrence = "lastOccurrence"
    }
}

struct DtPortfolioMetrics: Codable, Sendable {
    let critical: Int64
    let high: Int64
    let medium: Int64
    let low: Int64
    let unassigned: Int64
    let vulnerabilities: Int64?
    let findingsTotal: Int64
    let findingsAudited: Int64
    let findingsUnaudited: Int64
    let suppressions: Int64
    let inheritedRiskScore: Double
    let policyViolationsFail: Int64
    let policyViolationsWarn: Int64
    let policyViolationsInfo: Int64
    let policyViolationsTotal: Int64
    let projects: Int64

    enum CodingKeys: String, CodingKey {
        case critical, high, medium, low, unassigned, vulnerabilities, suppressions, projects
        case findingsTotal = "findingsTotal"
        case findingsAudited = "findingsAudited"
        case findingsUnaudited = "findingsUnaudited"
        case inheritedRiskScore = "inheritedRiskScore"
        case policyViolationsFail = "policyViolationsFail"
        case policyViolationsWarn = "policyViolationsWarn"
        case policyViolationsInfo = "policyViolationsInfo"
        case policyViolationsTotal = "policyViolationsTotal"
    }
}

// MARK: - Policy Violations

struct DtPolicyCondition: Codable, Sendable {
    let uuid: String
    let subject: String
    let `operator`: String
    let value: String
    let policy: DtPolicyRef

    enum CodingKeys: String, CodingKey {
        case uuid, subject, value, policy
        case `operator` = "operator"
    }
}

struct DtPolicyRef: Codable, Sendable {
    let uuid: String
    let name: String
    let violationState: String

    enum CodingKeys: String, CodingKey {
        case uuid, name
        case violationState = "violationState"
    }
}

struct DtPolicyViolation: Codable, Identifiable, Sendable {
    let uuid: String
    let type: String
    let component: DtComponent
    let policyCondition: DtPolicyCondition

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, type, component
        case policyCondition = "policyCondition"
    }
}

// MARK: - Policies (Full)

struct DtPolicyConditionFull: Codable, Identifiable, Sendable {
    let uuid: String
    let subject: String
    let `operator`: String
    let value: String

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, subject, value
        case `operator` = "operator"
    }
}

struct DtPolicyFull: Codable, Identifiable, Sendable {
    let uuid: String
    let name: String
    let violationState: String
    let includeChildren: Bool?
    let policyConditions: [DtPolicyConditionFull]
    let projects: [DtProject]
    let tags: [DtPolicyTag]

    var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid, name, projects, tags
        case violationState = "violationState"
        case includeChildren = "includeChildren"
        case policyConditions = "policyConditions"
    }
}

struct DtPolicyTag: Codable, Sendable {
    let name: String?
}

// MARK: - Analysis Update Request

struct UpdateDtAnalysisRequest: Encodable, Sendable {
    let projectUuid: String
    let componentUuid: String
    let vulnerabilityUuid: String
    let state: String
    let justification: String?
    let details: String?
    let suppressed: Bool

    enum CodingKeys: String, CodingKey {
        case state, justification, details, suppressed
        case projectUuid = "project_uuid"
        case componentUuid = "component_uuid"
        case vulnerabilityUuid = "vulnerability_uuid"
    }
}

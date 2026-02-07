import Foundation

struct RepoSecurityConfig: Codable, Sendable {
    var scanEnabled: Bool
    var scanOnUpload: Bool
    var scanOnProxy: Bool
    var blockOnPolicyViolation: Bool
    var severityThreshold: String

    enum CodingKeys: String, CodingKey {
        case scanEnabled = "scan_enabled"
        case scanOnUpload = "scan_on_upload"
        case scanOnProxy = "scan_on_proxy"
        case blockOnPolicyViolation = "block_on_policy_violation"
        case severityThreshold = "severity_threshold"
    }
}

struct RepoSecurityInfoResponse: Codable, Sendable {
    let config: RepoSecurityConfig?
}

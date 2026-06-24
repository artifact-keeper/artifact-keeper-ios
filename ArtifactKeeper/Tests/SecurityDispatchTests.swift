import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
import ArtifactKeeperClient
@testable import ArtifactKeeper

// Path-pinning tests for the SDK-backed Security/SBOM methods on APIClient.
//
// These assert the actual HTTP request path and method each APIClient method dispatches,
// catching operation-dispatch drift (calling the wrong generated operation) that model
// mapping tests cannot see. A recording transport captures the request and returns a
// minimal valid body so the method decodes and returns normally.

/// A ClientTransport that records the last request and replies with a canned 200 body
/// keyed by operationID.
final class RecordingTransport: ClientTransport, @unchecked Sendable {
    struct Recorded: Sendable {
        let path: String
        let method: String
        let operationID: String
    }

    private(set) var last: Recorded?

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        last = Recorded(
            path: request.path ?? "",
            method: request.method.rawValue,
            operationID: operationID
        )

        let json = Self.cannedBody(for: operationID)
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(json))
    }

    /// A 200 body for each operation. List/array shapes decode cleanly; for the SBOM
    /// shape we return an empty object so decode fails after the request is recorded.
    /// These are dispatch tests: the request is captured before the body is decoded, so a
    /// decode failure does not affect the path/method assertions (callers use `try?`).
    private static func cannedBody(for operationID: String) -> String {
        switch operationID {
        case "list_artifact_scans", "list_findings", "list_repo_scans":
            return #"{"items":[],"total":0}"#
        case "get_sbom_components", "get_all_scores", "list_scan_configs", "list_gates",
             "list_format_handlers":
            return "[]"
        default:
            return "{}"
        }
    }
}

/// The request path without its query string.
private func pathComponent(_ path: String?) -> String {
    guard let path else { return "" }
    return String(path.split(separator: "?", maxSplits: 1)[0])
}

@Suite("Security SDK Dispatch Tests")
struct SecurityDispatchTests {

    /// Build an APIClient wired to a RecordingTransport via an injected SDK client.
    private func makeClient() async -> (APIClient, RecordingTransport) {
        let transport = RecordingTransport()
        let sdk = Client(
            serverURL: URL(string: "https://example.test")!,
            transport: transport
        )
        let api = APIClient(baseURL: "https://example.test", session: .shared)
        await api.setSDKClientForTesting(sdk)
        return (api, transport)
    }

    @Test func listArtifactScansHitsArtifactScansPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listArtifactScans(artifactId: "abc123")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/security/artifacts/abc123/scans")
        #expect(rec?.operationID == "list_artifact_scans")
    }

    @Test func listFindingsHitsScanFindingsPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listFindings(scanId: "scan-9")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/security/scans/scan-9/findings")
        #expect(rec?.operationID == "list_findings")
    }

    @Test func getSbomByArtifactHitsByArtifactPath() async throws {
        let (api, transport) = await makeClient()

        // Decode of the canned body is irrelevant here: the transport records the request
        // before the body is decoded, so `try?` keeps the dispatch assertions meaningful.
        _ = try? await api.getSbomByArtifact(artifactId: "art-7")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/sbom/by-artifact/art-7")
        #expect(rec?.operationID == "get_sbom_by_artifact")
    }

    @Test func getSbomComponentsHitsComponentsPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.getSbomComponents(sbomId: "sbom-3")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/sbom/sbom-3/components")
        #expect(rec?.operationID == "get_sbom_components")
    }

    // MARK: - Dashboard cluster

    @Test func getSecurityDashboardHitsDashboardPath() async throws {
        let (api, transport) = await makeClient()

        // The canned body does not decode into DashboardResponse; the request is recorded
        // before decode, so `try?` keeps the dispatch assertions meaningful.
        _ = try? await api.getSecurityDashboard()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/security/dashboard")
        #expect(rec?.operationID == "get_dashboard")
    }

    @Test func getSecurityScoresHitsScoresPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.getSecurityScores()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/security/scores")
        #expect(rec?.operationID == "get_all_scores")
    }

    @Test func acknowledgeFindingHitsAcknowledgePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.acknowledgeFinding(id: "find-1", reason: "false positive")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(pathComponent(rec?.path) == "/api/v1/security/findings/find-1/acknowledge")
        #expect(rec?.operationID == "acknowledge_finding")
    }

    @Test func revokeAcknowledgmentHitsAcknowledgePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.revokeFindingAcknowledgment(id: "find-2")

        let rec = transport.last
        #expect(rec?.method == "DELETE")
        #expect(pathComponent(rec?.path) == "/api/v1/security/findings/find-2/acknowledge")
        #expect(rec?.operationID == "revoke_acknowledgment")
    }

    @Test func triggerScanHitsScanPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.triggerScan(artifactId: "art-1")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(pathComponent(rec?.path) == "/api/v1/security/scan")
        #expect(rec?.operationID == "trigger_scan")
    }

    @Test func listScanConfigsHitsConfigsPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listScanConfigs()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/security/configs")
        #expect(rec?.operationID == "list_scan_configs")
    }

    // MARK: - Quality Gates & Health cluster

    @Test func listQualityGatesHitsGatesPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listQualityGates()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/quality/gates")
        #expect(rec?.operationID == "list_gates")
    }

    @Test func getQualityGateHitsGateByIdPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getQualityGate(id: "gate-3")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/quality/gates/gate-3")
        #expect(rec?.operationID == "get_gate")
    }

    @Test func evaluateGateHitsEvaluatePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.evaluateGate(artifactId: "art-42")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(pathComponent(rec?.path) == "/api/v1/quality/gates/evaluate/art-42")
        #expect(rec?.operationID == "evaluate_gate")
    }

    @Test func getHealthDashboardHitsDashboardPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getHealthDashboard()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/quality/health/dashboard")
        #expect(rec?.operationID == "get_health_dashboard")
    }

    // MARK: - Repository-scoped scans

    @Test func listRepoScansHitsRepoScansPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listRepoScans(repoKey: "maven-prod")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/repositories/maven-prod/security/scans")
        #expect(rec?.operationID == "list_repo_scans")
    }

    // MARK: - Quality health drilldowns

    @Test func getRepoHealthHitsRepoHealthPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getRepoHealth(repoKey: "maven-prod")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/quality/health/repositories/maven-prod")
        #expect(rec?.operationID == "get_repo_health")
    }

    @Test func getArtifactHealthHitsArtifactHealthPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getArtifactHealth(artifactId: "art-88")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(pathComponent(rec?.path) == "/api/v1/quality/health/artifacts/art-88")
        #expect(rec?.operationID == "get_artifact_health")
    }
}

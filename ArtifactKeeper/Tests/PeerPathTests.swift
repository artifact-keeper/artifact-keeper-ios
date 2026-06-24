import Testing
import Foundation
@testable import ArtifactKeeper

// Path-pinning tests for the peer detail / identity / connections endpoints used
// by PeersView and PeerDetailView. Each test drives the real APIClient method
// (not a hand-built URL) against a MockSession (per-test isolated handler,
// defined in APIClientNetworkTests.swift) and asserts the exact 1.2.1 path and
// method. Each test owns its MockSession, so the suite is parallel-safe.

private func peerOk(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
}

private final class PeerCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(method: String, path: String)] = []
    func add(_ method: String, _ path: String) {
        lock.lock(); values.append((method, path)); lock.unlock()
    }
    func contains(method: String, path: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return values.contains { $0.method == method && $0.path == path }
    }
}

private let peerJSON = """
{"id":"peer-1","name":"East","endpoint_url":"https://east.example.com","status":"online",
 "region":"us-east","cache_size_bytes":1000,"cache_used_bytes":500,"cache_usage_percent":50.0,
 "last_heartbeat_at":null,"last_sync_at":null,"created_at":"2026-06-23T00:00:00Z",
 "api_key":"k","is_local":false}
"""

@Suite("Peer Path Tests")
struct PeerPathTests {

    @Test func getPeerIdentityHitsIdentityPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PeerCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return peerOk(request.url!, #"{"peer_id":"p-1","name":"Local","endpoint_url":"https://local.example.com"}"#)
        }

        _ = try await mock.client.getPeerIdentity()

        #expect(log.contains(method: "GET", path: "/api/v1/peers/identity"))
    }

    @Test func getPeerHitsPeerIdPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PeerCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return peerOk(request.url!, peerJSON)
        }

        _ = try await mock.client.getPeer(id: "peer-1")

        #expect(log.contains(method: "GET", path: "/api/v1/peers/peer-1"))
    }

    @Test func listPeerConnectionsHitsConnectionsPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PeerCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return peerOk(request.url!, "[]")
        }

        _ = try await mock.client.listPeerConnections(id: "peer-1")

        #expect(log.contains(method: "GET", path: "/api/v1/peers/peer-1/connections"))
    }
}

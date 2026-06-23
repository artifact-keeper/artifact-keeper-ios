import Testing
import Foundation
@testable import ArtifactKeeper

// Path-pinning tests for the webhook lifecycle and delivery-history endpoints
// used by WebhooksView and WebhookDeliveriesView. These call APIClient.request /
// requestVoid against a MockSession (per-test isolated handler, defined in
// APIClientNetworkTests.swift) and assert the exact 1.2.1 path and HTTP method,
// so a renamed path or wrong verb is caught here. Each test owns its MockSession,
// so the suite is safe under Swift Testing's parallel execution.

private func webhookOk(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
}

/// Records the (method, path) pairs a sequence of requests hits.
private final class WebhookCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(method: String, path: String)] = []
    func add(_ method: String, _ path: String) {
        lock.lock(); values.append((method, path)); lock.unlock()
    }
    var calls: [(method: String, path: String)] {
        lock.lock(); defer { lock.unlock() }; return values
    }
    func contains(method: String, path: String) -> Bool {
        calls.contains { $0.method == method && $0.path == path }
    }
}

@Suite("Webhook Path Tests")
struct WebhookPathTests {

    @Test func listDeliveriesHitsDeliveriesPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = WebhookCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return webhookOk(request.url!, #"{"items":[],"total":0}"#)
        }

        let _: WebhookDeliveryListResponse = try await mock.client.request(
            "/api/v1/webhooks/wh-1/deliveries"
        )

        #expect(log.contains(method: "GET", path: "/api/v1/webhooks/wh-1/deliveries"))
    }

    @Test func redeliverHitsRedeliverPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = WebhookCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return webhookOk(request.url!, """
            {"id":"del-9","webhook_id":"wh-1","event":"artifact_uploaded","payload":{},
             "success":true,"attempts":1,"created_at":"2026-06-23T00:00:00Z"}
            """)
        }

        let _: WebhookDelivery = try await mock.client.request(
            "/api/v1/webhooks/wh-1/deliveries/del-9/redeliver",
            method: "POST"
        )

        #expect(log.contains(method: "POST", path: "/api/v1/webhooks/wh-1/deliveries/del-9/redeliver"))
    }

    @Test func rotateSecretHitsRotatePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = WebhookCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return webhookOk(request.url!, """
            {"id":"wh-1","secret":"whsec_new","secret_digest":"sha256:abc",
             "previous_secret_expires_at":"2026-06-24T00:00:00Z"}
            """)
        }

        let _: RotateWebhookSecretResponse = try await mock.client.request(
            "/api/v1/webhooks/wh-1/rotate-secret",
            method: "POST"
        )

        #expect(log.contains(method: "POST", path: "/api/v1/webhooks/wh-1/rotate-secret"))
    }

    @Test func enableHitsEnablePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = WebhookCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return webhookOk(request.url!, "")
        }

        try await mock.client.requestVoid("/api/v1/webhooks/wh-1/enable", method: "POST")

        #expect(log.contains(method: "POST", path: "/api/v1/webhooks/wh-1/enable"))
    }

    @Test func disableHitsDisablePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = WebhookCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return webhookOk(request.url!, "")
        }

        try await mock.client.requestVoid("/api/v1/webhooks/wh-1/disable", method: "POST")

        #expect(log.contains(method: "POST", path: "/api/v1/webhooks/wh-1/disable"))
    }

    @Test func testWebhookHitsTestPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = WebhookCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return webhookOk(request.url!, #"{"success":true,"status_code":200}"#)
        }

        let _: TestWebhookResponse = try await mock.client.request(
            "/api/v1/webhooks/wh-1/test",
            method: "POST"
        )

        #expect(log.contains(method: "POST", path: "/api/v1/webhooks/wh-1/test"))
    }
}

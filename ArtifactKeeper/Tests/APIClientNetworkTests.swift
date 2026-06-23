import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - Thread-safe Tracker

/// A sendable class used to track whether a callback was invoked.
/// Uses nonisolated(unsafe) since it is only used in sequential test code.
final class AuthFailureTracker: Sendable {
    nonisolated(unsafe) var wasCalled = false
    func markCalled() { wasCalled = true }
}

/// Thread-safe counter for use inside @Sendable mock handlers, which cannot
/// capture a mutable local var.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    @discardableResult
    func increment() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

// MARK: - Mock URL Protocol

typealias MockRequestHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

/// A URLProtocol that returns stubbed responses for testing. Handlers are stored
/// per session (keyed by an id injected into the session's headers) in a
/// thread-safe registry, NOT in a single global. Swift Testing runs suites in
/// parallel, and a shared global handler caused concurrent tests to overwrite and
/// read each other's stub. Per-session isolation makes every test's APIClient see
/// only its own handler, so the suites are safe to run in parallel.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    static let sessionHeader = "X-Mock-Session-ID"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: MockRequestHandler] = [:]

    static func setHandler(for id: String, _ handler: @escaping MockRequestHandler) {
        lock.lock(); defer { lock.unlock() }
        handlers[id] = handler
    }

    static func handler(for id: String) -> MockRequestHandler? {
        lock.lock(); defer { lock.unlock() }
        return handlers[id]
    }

    static func removeHandler(for id: String) {
        lock.lock(); defer { lock.unlock() }
        handlers[id] = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: MockURLProtocol.sessionHeader) ?? ""
        guard let handler = MockURLProtocol.handler(for: id) else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No request handler set for session \(id)"
            ])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Per-test mock session

/// A test-scoped APIClient bound to its own MockURLProtocol handler slot. Each
/// call to makeTestClient (and the token/artifact variants) gets a unique session
/// id, so setting `mock.handler` only affects that client, even under parallel
/// test execution.
final class MockSession: @unchecked Sendable {
    let id: String
    let client: APIClient

    init(baseURL: String) {
        let id = UUID().uuidString
        self.id = id
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.timeoutIntervalForRequest = 5
        config.httpAdditionalHeaders = [MockURLProtocol.sessionHeader: id]
        let session = URLSession(configuration: config)
        self.client = APIClient(baseURL: baseURL, session: session)
    }

    /// Install the stub handler for this session only.
    var handler: MockRequestHandler? {
        get { MockURLProtocol.handler(for: id) }
        set {
            if let newValue { MockURLProtocol.setHandler(for: id, newValue) }
            else { MockURLProtocol.removeHandler(for: id) }
        }
    }

    deinit { MockURLProtocol.removeHandler(for: id) }
}

// MARK: - Helper to create a testable APIClient

/// Creates a MockSession (APIClient + isolated handler slot) for the network tests.
private func makeTestSession(baseURL: String = "https://test-api.example.com") -> MockSession {
    MockSession(baseURL: baseURL)
}

/// A simple Codable struct for testing generic request decoding.
struct TestResponsePayload: Codable, Sendable {
    let id: String
    let name: String
    let count: Int
}

/// A simple Codable struct for testing request bodies.
struct TestRequestBody: Codable, Sendable {
    let action: String
    let value: Int
}

// Each test uses its own MockSession (isolated handler slot), so the suite is
// safe to run in parallel with others.
@Suite("APIClient Network Tests")
struct APIClientNetworkTests {

    // MARK: - testConnection

    @Test func testConnectionSucceeds() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"status\": \"healthy\"}".utf8))
        }

        try await mock.client.testConnection(to: "https://test-api.example.com")
    }

    @Test func testConnectionFailsOnServerError() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            try await mock.client.testConnection(to: "https://test-api.example.com")
            Issue.record("Expected httpError to be thrown")
        } catch {
            #expect(error is APIError)
        }
    }

    @Test func testConnectionFailsOnInvalidURL() async {
        let mock = makeTestSession()
        do {
            try await mock.client.testConnection(to: "")
            Issue.record("Expected error for empty URL")
        } catch {
            #expect(Bool(true))
        }
    }

    @Test func testConnectionUsesCorrectTimeout() async {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.timeoutInterval == 10)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try? await mock.client.testConnection(to: "https://test-api.example.com")
    }

    // MARK: - request<T> Tests

    @Test func requestDecodesSuccessfulResponse() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let json = """
            {"id": "42", "name": "Widget", "count": 10}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result: TestResponsePayload = try await mock.client.request("/api/v1/items/42")
        #expect(result.id == "42")
        #expect(result.name == "Widget")
        #expect(result.count == 10)
    }

    @Test func requestIncludesBearerToken() async throws {
        let mock = makeTestSession()
        await mock.client.setToken("test-bearer-token")

        mock.handler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader == "Bearer test-bearer-token")
            let json = """
            {"id": "1", "name": "AuthItem", "count": 0}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let _: TestResponsePayload = try await mock.client.request("/api/v1/items/1")
    }

    @Test func requestSendsNoAuthHeaderWithoutToken() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader == nil)
            let json = """
            {"id": "1", "name": "NoAuth", "count": 0}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let _: TestResponsePayload = try await mock.client.request("/api/v1/items/1")
    }

    @Test func requestSetsContentTypeJSON() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let contentType = request.value(forHTTPHeaderField: "Content-Type")
            #expect(contentType == "application/json")
            let json = """
            {"id": "1", "name": "CT", "count": 0}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let _: TestResponsePayload = try await mock.client.request("/api/v1/test")
    }

    @Test func requestWithPOSTMethodAndBody() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "POST")
            let json = """
            {"id": "new", "name": "Created", "count": 42}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let body = TestRequestBody(action: "create", value: 42)
        let result: TestResponsePayload = try await mock.client.request(
            "/api/v1/items",
            method: "POST",
            body: body
        )
        #expect(result.id == "new")
    }

    @Test func requestThrowsOnHTTP4xxError() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"error\": \"not found\"}".utf8))
        }

        do {
            let _: TestResponsePayload = try await mock.client.request("/api/v1/items/missing")
            Issue.record("Expected httpError")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 404")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestThrowsOnHTTP5xxError() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            let _: TestResponsePayload = try await mock.client.request("/api/v1/items")
            Issue.record("Expected httpError")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 500")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestThrowsInvalidURLForEmptyBase() async {
        let mock = makeTestSession(baseURL: "")

        do {
            let _: TestResponsePayload = try await mock.client.request("/api/v1/items")
            Issue.record("Expected invalidURL")
        } catch let error as APIError {
            #expect(error.errorDescription == "Invalid URL")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestWith401TriggersAuthFailureWhenNoRefreshHandler() async {
        let mock = makeTestSession()
        let tracker = AuthFailureTracker()

        await mock.client.setAuthFailureHandler {
            tracker.markCalled()
        }

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"error\": \"unauthorized\"}".utf8))
        }

        do {
            let _: TestResponsePayload = try await mock.client.request("/api/v1/protected")
            Issue.record("Expected httpError")
        } catch {
            #expect(tracker.wasCalled == true)
        }
    }

    @Test func requestWith401RetriesAfterSuccessfulRefresh() async throws {
        let mock = makeTestSession()

        let requestCount = Counter()
        mock.handler = { request in
                        if requestCount.increment() == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            } else {
                let json = """
                {"id": "retried", "name": "Success", "count": 1}
                """
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data(json.utf8))
            }
        }

        await mock.client.setTokenRefreshHandler {
            return true
        }

        let result: TestResponsePayload = try await mock.client.request("/api/v1/protected")
        #expect(result.id == "retried")
        #expect(requestCount.count == 2)
    }

    @Test func requestWith401FailsWhenRefreshFails() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await mock.client.setTokenRefreshHandler {
            return false
        }

        do {
            let _: TestResponsePayload = try await mock.client.request("/api/v1/protected")
            Issue.record("Expected httpError 401")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 401")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestWithDELETEMethod() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "DELETE")
            let json = """
            {"id": "deleted", "name": "Gone", "count": 0}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result: TestResponsePayload = try await mock.client.request("/api/v1/items/1", method: "DELETE")
        #expect(result.id == "deleted")
    }

    @Test func requestWithPATCHMethod() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "PATCH")
            let json = """
            {"id": "patched", "name": "Updated", "count": 5}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result: TestResponsePayload = try await mock.client.request(
            "/api/v1/items/1",
            method: "PATCH",
            body: TestRequestBody(action: "update", value: 5)
        )
        #expect(result.name == "Updated")
    }

    @Test func requestWithPUTMethod() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "PUT")
            let json = """
            {"id": "put", "name": "Replaced", "count": 99}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result: TestResponsePayload = try await mock.client.request("/api/v1/items/1", method: "PUT")
        #expect(result.count == 99)
    }

    // MARK: - requestVoid Tests

    @Test func requestVoidSucceeds() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await mock.client.requestVoid("/api/v1/items/1/archive")
    }

    @Test func requestVoidThrowsOn4xx() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"error\": \"forbidden\"}".utf8))
        }

        do {
            try await mock.client.requestVoid("/api/v1/admin/action")
            Issue.record("Expected httpError 403")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 403")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestVoidThrowsOn5xx() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 502,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            try await mock.client.requestVoid("/api/v1/action")
            Issue.record("Expected httpError 502")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 502")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestVoidThrowsInvalidURLForEmptyBase() async {
        let mock = makeTestSession(baseURL: "")

        do {
            try await mock.client.requestVoid("/api/v1/action")
            Issue.record("Expected invalidURL")
        } catch let error as APIError {
            #expect(error.errorDescription == "Invalid URL")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestVoidWith401TriggersAuthFailure() async {
        let mock = makeTestSession()
        let tracker = AuthFailureTracker()

        await mock.client.setAuthFailureHandler {
            tracker.markCalled()
        }

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            try await mock.client.requestVoid("/api/v1/protected")
            Issue.record("Expected httpError 401")
        } catch {
            #expect(tracker.wasCalled == true)
        }
    }

    @Test func requestVoidWith401RetriesOnRefresh() async throws {
        let mock = makeTestSession()

        let requestCount = Counter()
        mock.handler = { request in
                        let statusCode = requestCount.increment() == 1 ? 401 : 200
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await mock.client.setTokenRefreshHandler {
            return true
        }

        try await mock.client.requestVoid("/api/v1/protected", method: "DELETE")
        #expect(requestCount.count == 2)
    }

    @Test func requestVoidWith401FailsOnRefreshFailure() async {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await mock.client.setTokenRefreshHandler {
            return false
        }

        do {
            try await mock.client.requestVoid("/api/v1/protected")
            Issue.record("Expected httpError 401")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 401")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestVoidWithBody() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let body = TestRequestBody(action: "fire", value: 1)
        try await mock.client.requestVoid("/api/v1/trigger", method: "POST", body: body)
    }

    @Test func requestVoidWithDELETEMethod() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await mock.client.requestVoid("/api/v1/items/1", method: "DELETE")
    }

    @Test func requestVoidWith401RetryButRetryAlsoFails() async {
        let mock = makeTestSession()

        var alwaysReturn401 = true
        _ = alwaysReturn401
        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await mock.client.setTokenRefreshHandler {
            return true // Refresh "succeeds" but retry also returns 401
        }

        do {
            try await mock.client.requestVoid("/api/v1/protected")
            Issue.record("Expected httpError")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 401")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - 401 Retry Edge Cases

    @Test func requestRetryReturnsNewData() async throws {
        let mock = makeTestSession()

        let attempt = Counter()
        mock.handler = { request in
                        if attempt.increment() == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
            let json = """
            {"id": "refreshed", "name": "After refresh", "count": 99}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        await mock.client.setTokenRefreshHandler { return true }

        let result: TestResponsePayload = try await mock.client.request("/api/v1/data")
        #expect(result.id == "refreshed")
        #expect(result.count == 99)
    }

    @Test func requestRetryWithFailedRetryResponse() async {
        let mock = makeTestSession()

        let attempt = Counter()
        mock.handler = { request in
                        if attempt.increment() == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
            // Retry returns 500 instead of success
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await mock.client.setTokenRefreshHandler { return true }

        do {
            let _: TestResponsePayload = try await mock.client.request("/api/v1/data")
            Issue.record("Expected httpError")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 500")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func requestVoidRetryWithFailedRetryResponse() async {
        let mock = makeTestSession()

        let attempt = Counter()
        mock.handler = { request in
                        if attempt.increment() == 1 {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
            // Retry returns 500
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await mock.client.setTokenRefreshHandler { return true }

        do {
            try await mock.client.requestVoid("/api/v1/data")
            Issue.record("Expected httpError")
        } catch let error as APIError {
            #expect(error.errorDescription == "HTTP error 500")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Request with nil body

    @Test func requestWithNilBody() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpBody == nil)
            let json = """
            {"id": "nobody", "name": "NoBody", "count": 0}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result: TestResponsePayload = try await mock.client.request("/api/v1/items/1")
        #expect(result.id == "nobody")
    }

    @Test func requestVoidWithNilBody() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await mock.client.requestVoid("/api/v1/items/1/touch", method: "POST")
    }

    // MARK: - Higher-level API Method Tests

    @Test func updateProfileCallsRequestWithPUT() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url?.path == "/api/v1/profile")
            let json = """
            {
                "id": "u1", "username": "testuser", "email": "new@test.com",
                "display_name": "New Name", "is_admin": false, "totp_enabled": false
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let profile = try await mock.client.updateProfile(displayName: "New Name", email: "new@test.com")
        #expect(profile.displayName == "New Name")
    }

    // Token tests target the unified 1.2.1 surface: list via /api/v1/users/{id}/tokens
    // (preceded by a /api/v1/auth/me call to resolve the user id), create via
    // /api/v1/auth/tokens, delete via /api/v1/auth/tokens/{id}.

    @Test func listApiKeysCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let path = request.url?.path
            if path == "/api/v1/auth/me" {
                let me = """
                {"id": "u1", "username": "testuser", "email": "a@b.c", "is_admin": false, "totp_enabled": false}
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(me.utf8))
            }
            #expect(path == "/api/v1/users/u1/tokens")
            let json = """
            {
                "items": [
                    {
                        "id": "k1", "name": "CI Key", "token_prefix": "ak_",
                        "created_at": "2024-01-01T00:00:00Z", "expires_at": null,
                        "last_used_at": null, "scopes": ["read"]
                    }
                ]
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let keys = try await mock.client.listApiKeys()
        #expect(keys.count == 1)
        #expect(keys[0].name == "CI Key")
    }

    @Test func createApiKeyCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/auth/tokens")
            let json = """
            {"id": "k2", "name": "Deploy", "token": "ak_full_key_value"}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result = try await mock.client.createApiKey(name: "Deploy", scopes: ["write"], expiresInDays: 30)
        #expect(result.key == "ak_full_key_value")
    }

    @Test func deleteApiKeyCallsRequestVoid() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.path == "/api/v1/auth/tokens/key-123")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await mock.client.deleteApiKey("key-123")
    }

    @Test func listAccessTokensCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            let path = request.url?.path
            if path == "/api/v1/auth/me" {
                let me = """
                {"id": "u2", "username": "testuser", "email": "a@b.c", "is_admin": false, "totp_enabled": false}
                """
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(me.utf8))
            }
            #expect(path == "/api/v1/users/u2/tokens")
            let json = """
            {
                "items": [
                    {
                        "id": "t1", "name": "Read Token", "token_prefix": "at_",
                        "created_at": "2024-01-01T00:00:00Z", "expires_at": null,
                        "last_used_at": null, "scopes": ["read"]
                    }
                ]
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let tokens = try await mock.client.listAccessTokens()
        #expect(tokens.count == 1)
        #expect(tokens[0].name == "Read Token")
    }

    @Test func createAccessTokenCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/auth/tokens")
            let json = """
            {"id": "t2", "name": "CI Token", "token": "at_full_token_value"}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let result = try await mock.client.createAccessToken(name: "CI Token", scopes: ["read", "write"], expiresInDays: nil)
        #expect(result.token == "at_full_token_value")
    }

    @Test func deleteAccessTokenCallsRequestVoid() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url?.path == "/api/v1/auth/tokens/token-456")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        try await mock.client.deleteAccessToken("token-456")
    }

    @Test func listStagingReposCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.url?.path == "/api/v1/staging/repositories")
            let json = """
            {"items": []}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let repos = try await mock.client.listStagingRepos()
        #expect(repos.isEmpty)
    }

    @Test func getRepoSecurityConfigCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.url?.path == "/api/v1/repositories/maven-local/security")
            let json = """
            {
                "config": {
                    "scan_enabled": true,
                    "scan_on_upload": true,
                    "scan_on_proxy": false,
                    "block_on_policy_violation": false,
                    "severity_threshold": "critical"
                }
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let config = try await mock.client.getRepoSecurityConfig(repoKey: "maven-local")
        #expect(config.scanEnabled == true)
    }

    @Test func updateRepoSecurityConfigCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "PUT")
            let json = """
            {
                "scan_enabled": true,
                "scan_on_upload": true,
                "scan_on_proxy": true,
                "block_on_policy_violation": true,
                "severity_threshold": "high"
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let config = RepoSecurityConfig(
            scanEnabled: true,
            scanOnUpload: true,
            scanOnProxy: true,
            blockOnPolicyViolation: true,
            severityThreshold: "high"
        )
        let result = try await mock.client.updateRepoSecurityConfig(repoKey: "maven-local", config: config)
        #expect(result.scanEnabled == true)
    }

    @Test func updateRepositoryCallsRequest() async throws {
        let mock = makeTestSession()

        mock.handler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.path == "/api/v1/repositories/npm-local")
            let json = """
            {
                "id": "r1", "key": "npm-local", "name": "NPM Local Updated",
                "format": "npm", "repo_type": "local", "is_public": false,
                "description": "Updated repo",
                "storage_used_bytes": 0, "quota_bytes": null,
                "created_at": "2024-01-01T00:00:00Z", "updated_at": "2024-06-01T00:00:00Z"
            }
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let updateReq = UpdateRepositoryRequest(
            name: "NPM Local Updated",
            description: "Updated repo",
            isPublic: false
        )
        let repo = try await mock.client.updateRepository(key: "npm-local", request: updateReq)
        #expect(repo.name == "NPM Local Updated")
    }
}

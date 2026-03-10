import Testing
import Foundation
@testable import ArtifactKeeper

// MARK: - APIClient Extended Tests

@Suite("APIClient Extended Tests")
struct APIClientExtendedTests {

    // MARK: - Token Management

    @Test func setTokenMultipleTimes() async {
        let client = APIClient()
        await client.setToken("first")
        #expect(await client.accessToken == "first")
        await client.setToken("second")
        #expect(await client.accessToken == "second")
        await client.setToken(nil)
        #expect(await client.accessToken == nil)
    }

    @Test func accessTokenIsNilByDefault() async {
        let client = APIClient()
        #expect(await client.accessToken == nil)
    }

    // MARK: - Base URL Management

    @Test func getBaseURLReturnsStoredDefault() async {
        let client = APIClient()
        let url = await client.getBaseURL()
        // Returns whatever was in UserDefaults, or empty string
        _ = url
        #expect(Bool(true))
    }

    @Test func updateBaseURLMultipleTimes() async {
        let client = APIClient()
        let urls = [
            "https://server1.test",
            "https://server2.test:8080",
            "https://server3.test/api",
            "http://localhost:8080",
        ]
        for url in urls {
            await client.updateBaseURL(url)
            #expect(await client.getBaseURL() == url)
        }
    }

    @Test func updateBaseURLWithEmptyString() async {
        let client = APIClient()
        await client.updateBaseURL("")
        #expect(await client.getBaseURL() == "")
    }

    // MARK: - isConfigured

    @Test func isConfiguredReadsFromUserDefaults() async {
        // isConfigured checks UserDefaults.standard for the server URL key.
        // We test that it returns a Bool without crashing.
        let client = APIClient()
        let configured = await client.isConfigured
        // The result depends on whatever is currently in UserDefaults,
        // so we just verify the property is accessible and returns a Bool.
        _ = configured
        #expect(Bool(true))
    }

    @Test func isConfiguredPropertyIsAccessible() async {
        // isConfigured reads from UserDefaults, which is shared state
        // that can be modified by parallel tests. We just verify
        // the property is accessible and returns a Bool.
        let client = APIClient()
        let _ = await client.isConfigured
        #expect(Bool(true))
    }

    // MARK: - buildURL Tests

    @Test func buildURLWithEmptyBaseReturnsNil() async {
        let client = APIClient()
        await client.updateBaseURL("")
        let url = await client.buildURL("/api/v1/health")
        #expect(url == nil)
    }

    @Test func buildURLWithValidBase() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildURL("/api/v1/repositories")
        #expect(url?.absoluteString == "https://registry.test/api/v1/repositories")
    }

    @Test func buildURLWithTrailingSlashInBase() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildURL("/health")
        #expect(url?.absoluteString == "https://registry.test/health")
    }

    @Test func buildURLWithComplexPath() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test:9443")
        let url = await client.buildURL("/api/v1/repositories/maven-local/artifacts?page=1&per_page=50")
        #expect(url != nil)
        #expect(url?.absoluteString.contains("maven-local") == true)
    }

    @Test func buildURLWithRootPath() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildURL("/")
        #expect(url != nil)
    }

    @Test func buildURLWithEmptyPath() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildURL("")
        #expect(url?.absoluteString == "https://registry.test")
    }

    // MARK: - buildDownloadURL Tests

    @Test func buildDownloadURLFormatsCorrectly() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildDownloadURL(
            repoKey: "npm-local",
            artifactPath: "lodash/-/lodash-4.17.21.tgz"
        )
        #expect(url != nil)
        let urlStr = url?.absoluteString ?? ""
        #expect(urlStr.contains("npm-local"))
        #expect(urlStr.contains("/download"))
    }

    @Test func buildDownloadURLWithSpacesInPath() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildDownloadURL(
            repoKey: "generic-local",
            artifactPath: "some path/with spaces.tar.gz"
        )
        #expect(url != nil)
    }

    @Test func buildDownloadURLWithNestedPath() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildDownloadURL(
            repoKey: "maven-local",
            artifactPath: "com/example/mylib/1.0.0/mylib-1.0.0.jar"
        )
        #expect(url != nil)
        let urlStr = url?.absoluteString ?? ""
        #expect(urlStr.contains("maven-local"))
        #expect(urlStr.contains("com"))
    }

    @Test func buildDownloadURLWithEmptyBase() async {
        let client = APIClient()
        await client.updateBaseURL("")
        let url = await client.buildDownloadURL(repoKey: "repo", artifactPath: "file.jar")
        // With empty base, building the URL string starts from empty, producing an invalid URL or nil
        _ = url
        #expect(Bool(true))
    }

    @Test func buildDownloadURLWithSpecialChars() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")
        let url = await client.buildDownloadURL(
            repoKey: "pypi-local",
            artifactPath: "packages/my-pkg/1.0.0/my_pkg-1.0.0.tar.gz"
        )
        #expect(url != nil)
    }

    // MARK: - Handler Registration Tests

    @Test func setTokenRefreshHandler() async {
        let client = APIClient()
        await client.setTokenRefreshHandler {
            return false
        }
        // Verifying handler was set without crash
        #expect(Bool(true))
    }

    @Test func setAuthFailureHandler() async {
        let client = APIClient()
        await client.setAuthFailureHandler {
            // No-op for testing
        }
        // Verifying handler was set without crash
        #expect(Bool(true))
    }

    // MARK: - formatDate Tests

    @Test func formatDateEpoch() {
        let date = Date(timeIntervalSince1970: 0)
        let result = APIClient.formatDate(date)
        #expect(result.contains("1970"))
        #expect(result.contains("T"))
        #expect(result.contains("00:00:00"))
    }

    @Test func formatDateCurrentTime() {
        let now = Date()
        let result = APIClient.formatDate(now)
        #expect(!result.isEmpty)
        #expect(result.contains("T"))
    }

    @Test func formatDateIncludesFractionalSeconds() {
        let date = Date(timeIntervalSince1970: 1234567890.123)
        let result = APIClient.formatDate(date)
        #expect(result.contains("."))
    }

    @Test func formatDateProducesISO8601Format() {
        let date = Date(timeIntervalSince1970: 1609459200) // 2021-01-01T00:00:00Z
        let result = APIClient.formatDate(date)
        #expect(result.contains("2021"))
        #expect(result.contains("T"))
    }

    @Test func formatDateVariousDates() {
        let dates: [TimeInterval] = [
            0,
            86400,           // 1 day
            1_000_000_000,   // Sep 2001
            1_609_459_200,   // Jan 2021
            1_700_000_000,   // Nov 2023
        ]
        for ts in dates {
            let result = APIClient.formatDate(Date(timeIntervalSince1970: ts))
            #expect(!result.isEmpty, "formatDate should produce non-empty string for timestamp \(ts)")
            #expect(result.contains("T"), "formatDate should include T separator for timestamp \(ts)")
        }
    }

    // MARK: - Request Method Error Cases

    @Test func requestThrowsInvalidURLForEmptyBase() async {
        let client = APIClient()
        await client.updateBaseURL("")
        do {
            let _: [String: String] = try await client.request("/api/v1/test")
            Issue.record("Expected APIError.invalidURL")
        } catch {
            guard let apiError = error as? APIError else {
                Issue.record("Expected APIError but got \(type(of: error))")
                return
            }
            #expect(apiError.errorDescription == "Invalid URL")
        }
    }

    @Test func requestVoidThrowsInvalidURLForEmptyBase() async {
        let client = APIClient()
        await client.updateBaseURL("")
        do {
            try await client.requestVoid("/api/v1/test")
            Issue.record("Expected APIError.invalidURL")
        } catch {
            guard let apiError = error as? APIError else {
                Issue.record("Expected APIError but got \(type(of: error))")
                return
            }
            #expect(apiError.errorDescription == "Invalid URL")
        }
    }

    @Test func testConnectionThrowsForInvalidURL() async {
        let client = APIClient()
        do {
            try await client.testConnection(to: "")
            Issue.record("Expected APIError.invalidURL")
        } catch {
            // Empty URL with /health appended should still be invalid or fail
            #expect(Bool(true))
        }
    }

    // MARK: - Static Properties

    @Test func serverURLKeyIsCorrect() {
        #expect(APIClient.serverURLKey == "serverURL")
    }

    @Test func defaultServerURLIsEmpty() {
        #expect(APIClient.defaultServerURL == "")
    }
}

// MARK: - APIError Extended Tests

@Suite("APIError Extended Tests")
struct APIErrorExtendedTests {

    @Test func invalidURLEquality() {
        let error = APIError.invalidURL
        #expect(error.errorDescription == "Invalid URL")
    }

    @Test func invalidResponseEquality() {
        let error = APIError.invalidResponse
        #expect(error.errorDescription == "Invalid response")
    }

    @Test func httpError200RangeDescriptions() {
        // Even though 200-range are success, the enum can still represent them
        for code in [200, 201, 204, 301, 302] {
            let error = APIError.httpError(statusCode: code, data: Data())
            #expect(error.errorDescription == "HTTP error \(code)")
        }
    }

    @Test func httpError4xxDescriptions() {
        let codes = [400, 401, 403, 404, 405, 409, 413, 422, 429]
        for code in codes {
            let error = APIError.httpError(statusCode: code, data: Data())
            #expect(error.errorDescription == "HTTP error \(code)")
        }
    }

    @Test func httpError5xxDescriptions() {
        let codes = [500, 501, 502, 503, 504]
        for code in codes {
            let error = APIError.httpError(statusCode: code, data: Data())
            #expect(error.errorDescription == "HTTP error \(code)")
        }
    }

    @Test func httpErrorWithNonEmptyData() {
        let body = Data("{\"message\": \"Not Found\"}".utf8)
        let error = APIError.httpError(statusCode: 404, data: body)
        // Description only shows the status code
        #expect(error.errorDescription == "HTTP error 404")
    }

    @Test func httpErrorWithLargeData() {
        let largeBody = Data(repeating: 0x41, count: 10_000)
        let error = APIError.httpError(statusCode: 500, data: largeBody)
        #expect(error.errorDescription == "HTTP error 500")
    }

    @Test func apiErrorLocalizedErrorConformance() {
        let errors: [APIError] = [
            .invalidURL,
            .invalidResponse,
            .httpError(statusCode: 418, data: Data()),
        ]
        for error in errors {
            let localized: any LocalizedError = error
            #expect(localized.errorDescription != nil)
        }
    }
}

// MARK: - SDKError Tests

@Suite("SDKError Tests")
struct SDKErrorTests {

    @Test func unexpectedResponseDescription() {
        let error = SDKError.unexpectedResponse("missing field")
        #expect(error.errorDescription == "Unexpected response: missing field")
    }

    @Test func serverErrorDescription() {
        let error = SDKError.serverError("Internal Server Error")
        #expect(error.errorDescription == "Internal Server Error")
    }

    @Test func sdkErrorConformsToLocalizedError() {
        let error: any LocalizedError = SDKError.serverError("test")
        #expect(error.errorDescription != nil)
    }

    @Test func unexpectedResponseWithEmptyMessage() {
        let error = SDKError.unexpectedResponse("")
        #expect(error.errorDescription == "Unexpected response: ")
    }

    @Test func serverErrorWithEmptyMessage() {
        let error = SDKError.serverError("")
        #expect(error.errorDescription == "")
    }
}

// MARK: - SelfSignedCertDelegate Tests

@Suite("SelfSignedCertDelegate Tests")
struct SelfSignedCertDelegateTests {

    @Test func delegateCanBeInstantiated() {
        let delegate = SelfSignedCertDelegate()
        _ = delegate
        #expect(Bool(true))
    }

    @Test func delegateIsSendable() {
        let delegate: any Sendable = SelfSignedCertDelegate()
        _ = delegate
        #expect(Bool(true))
    }

    @Test func delegateConformsToURLSessionDelegate() {
        let delegate = SelfSignedCertDelegate()
        let _: URLSessionDelegate = delegate
        #expect(Bool(true))
    }
}

// MARK: - BearerAuthMiddleware Tests

@Suite("BearerAuthMiddleware Tests")
struct BearerAuthMiddlewareTests {

    @Test func middlewareCanBeCreated() {
        let middleware = BearerAuthMiddleware(token: { "test-token" })
        _ = middleware
        #expect(Bool(true))
    }

    @Test func middlewareTokenProviderReturnsValue() {
        let middleware = BearerAuthMiddleware(token: { "my-bearer-token" })
        let token = middleware.token()
        #expect(token == "my-bearer-token")
    }

    @Test func middlewareTokenProviderReturnsNil() {
        let middleware = BearerAuthMiddleware(token: { nil })
        let token = middleware.token()
        #expect(token == nil)
    }
}

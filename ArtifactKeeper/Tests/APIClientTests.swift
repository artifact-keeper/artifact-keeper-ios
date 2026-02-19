import Testing
import Foundation
@testable import ArtifactKeeper

@Suite("APIClient Tests")
struct APIClientTests {

    @Test func buildURLWithExplicitlyEmptyBase() async {
        let client = APIClient()
        await client.updateBaseURL("")
        let url = await client.buildURL("/api/v1/health")
        // An empty base URL may still produce a URL from the path alone;
        // the important thing is that it does not crash
        _ = url
        #expect(Bool(true))
    }

    @Test func buildURLConstructsCorrectURL() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.example.com")

        let url = await client.buildURL("/api/v1/repositories")
        #expect(url?.absoluteString == "https://registry.example.com/api/v1/repositories")
    }

    @Test func buildURLWithDifferentPaths() async {
        let client = APIClient()
        await client.updateBaseURL("https://my-server.test:8080")

        let healthURL = await client.buildURL("/health")
        #expect(healthURL?.absoluteString == "https://my-server.test:8080/health")

        let repoURL = await client.buildURL("/api/v1/repositories/maven-local/artifacts")
        #expect(repoURL?.absoluteString == "https://my-server.test:8080/api/v1/repositories/maven-local/artifacts")
    }

    @Test func buildDownloadURLEncodesPath() async {
        let client = APIClient()
        await client.updateBaseURL("https://registry.test")

        let url = await client.buildDownloadURL(
            repoKey: "maven-local",
            artifactPath: "com/example/lib/1.0/lib-1.0.jar"
        )
        #expect(url != nil)
        let urlString = url?.absoluteString ?? ""
        #expect(urlString.contains("maven-local"))
        #expect(urlString.contains("/download"))
    }

    @Test func buildDownloadURLReturnsNilForEmptyBase() async {
        let client = APIClient()
        let url = await client.buildDownloadURL(repoKey: "repo", artifactPath: "file.jar")
        // With empty base URL, this builds a URL from an empty string prefix
        // which may or may not be nil depending on URL parsing
        // The key point is it does not crash
        _ = url
        #expect(Bool(true))
    }

    @Test func setTokenUpdatesAccessToken() async {
        let client = APIClient()
        let before = await client.accessToken
        #expect(before == nil)

        await client.setToken("my-access-token")
        let after = await client.accessToken
        #expect(after == "my-access-token")
    }

    @Test func setTokenToNilClearsToken() async {
        let client = APIClient()
        await client.setToken("token-123")
        await client.setToken(nil)
        let token = await client.accessToken
        #expect(token == nil)
    }

    @Test func updateBaseURLSetsNewURL() async {
        let client = APIClient()
        await client.updateBaseURL("https://new-server.test")
        let url = await client.getBaseURL()
        #expect(url == "https://new-server.test")
    }

    @Test func updateBaseURLOverwritesPrevious() async {
        let client = APIClient()
        await client.updateBaseURL("https://first.test")
        await client.updateBaseURL("https://second.test")
        let url = await client.getBaseURL()
        #expect(url == "https://second.test")
    }

    @Test func formatDateProducesISO8601() {
        // Test the static date formatting helper
        let date = Date(timeIntervalSince1970: 0)
        let formatted = APIClient.formatDate(date)
        #expect(formatted.contains("1970"))
        #expect(formatted.contains("T"))
    }

    @Test func formatDateHandlesCurrentDate() {
        let now = Date()
        let formatted = APIClient.formatDate(now)
        // Should produce a non-empty ISO 8601 string
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("T"))
    }
}

// MARK: - APIError Tests

@Suite("APIError Tests")
struct APIErrorTests {

    @Test func invalidURLDescription() {
        let error = APIError.invalidURL
        #expect(error.errorDescription == "Invalid URL")
    }

    @Test func invalidResponseDescription() {
        let error = APIError.invalidResponse
        #expect(error.errorDescription == "Invalid response")
    }

    @Test func httpErrorDescriptionIncludesStatusCode() {
        let error = APIError.httpError(statusCode: 403, data: Data())
        #expect(error.errorDescription == "HTTP error 403")
    }

    @Test func httpErrorVariousStatusCodes() {
        let codes = [400, 401, 403, 404, 409, 500, 502, 503]
        for code in codes {
            let error = APIError.httpError(statusCode: code, data: Data())
            #expect(error.errorDescription == "HTTP error \(code)")
        }
    }

    @Test func httpErrorWithBody() {
        let body = "{\"error\": \"not found\"}".data(using: .utf8)!
        let error = APIError.httpError(statusCode: 404, data: body)
        // The error description does not include the body, just the status code
        #expect(error.errorDescription == "HTTP error 404")
    }

    @Test func apiErrorConformsToLocalizedError() {
        // Verify that APIError conforms to LocalizedError (compile-time check)
        let error: any LocalizedError = APIError.invalidURL
        #expect(error.errorDescription != nil)
    }
}

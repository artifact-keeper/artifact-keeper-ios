import Testing
import Foundation
@testable import ArtifactKeeper

@Test func appInitializes() {
    // Verify that APIError cases have the expected descriptions
    let urlErr = APIError.invalidURL
    #expect(urlErr.errorDescription == "Invalid URL")

    let responseErr = APIError.invalidResponse
    #expect(responseErr.errorDescription == "Invalid response")

    let httpErr = APIError.httpError(statusCode: 404, data: Data())
    #expect(httpErr.errorDescription == "HTTP error 404")
}

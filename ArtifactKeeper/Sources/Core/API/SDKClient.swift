import Foundation
import ArtifactKeeperClient
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

// MARK: - Bearer Auth Middleware

/// Middleware that injects Bearer token into requests.
struct BearerAuthMiddleware: ClientMiddleware {
    var token: @Sendable () -> String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        if let token = token() {
            request.headerFields[.authorization] = "Bearer \(token)"
        }
        return try await next(request, body, baseURL)
    }
}

// MARK: - SDK Client Wrapper

/// Manages the generated OpenAPI SDK `Client` instance, allowing base URL changes
/// and bearer-token injection.
actor SDKClient {
    static let shared = SDKClient()

    private(set) var client: Client
    private var serverURL: URL
    private var _token: String?

    /// Returns the current bearer token (thread-safe via actor).
    var token: String? { _token }

    init() {
        let stored = UserDefaults.standard.string(forKey: APIClient.serverURLKey) ?? ""
        let url = URL(string: stored) ?? URL(string: "http://localhost:8080")!
        self.serverURL = url
        self._token = nil

        // Build initial client
        self.client = SDKClient.makeClient(serverURL: url, tokenProvider: { nil })
    }

    func setToken(_ token: String?) {
        self._token = token
        rebuildClient()
    }

    func updateBaseURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        self.serverURL = url
        rebuildClient()
    }

    func getBaseURL() -> URL {
        serverURL
    }

    private func rebuildClient() {
        let capturedToken = _token
        self.client = SDKClient.makeClient(
            serverURL: serverURL,
            tokenProvider: { capturedToken }
        )
    }

    private static func makeClient(
        serverURL: URL,
        tokenProvider: @escaping @Sendable () -> String?
    ) -> Client {
        let authMiddleware = BearerAuthMiddleware(token: tokenProvider)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        let session = URLSession(
            configuration: config,
            delegate: SelfSignedCertDelegate(),
            delegateQueue: nil
        )
        let transport = URLSessionTransport(configuration: .init(session: session))
        return Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [authMiddleware]
        )
    }
}

// MARK: - Self-Signed Cert Delegate (shared)

/// URLSession delegate that accepts self-signed certificates for self-hosted servers.
final class SelfSignedCertDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

// MARK: - SDK Error Helpers

/// Maps SDK operation errors to the app's APIError type.
enum SDKError: LocalizedError {
    case unexpectedResponse(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse(let msg): return "Unexpected response: \(msg)"
        case .serverError(let msg): return msg
        }
    }
}

import Testing
import Foundation
@testable import ArtifactKeeper

// Path-pinning tests for the plugin list / detail / lifecycle endpoints used by
// PluginsView. These call APIClient.request / requestVoid against a MockSession
// (per-test isolated handler, defined in APIClientNetworkTests.swift) and assert
// the exact 1.2.1 path and HTTP method. Each test owns its MockSession, so the
// suite is safe under Swift Testing's parallel execution.

private func pluginOk(_ url: URL, _ body: String, status: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
}

/// Records the (method, path) pairs a sequence of requests hits.
private final class PluginCallLog: @unchecked Sendable {
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

private let pluginJSON = """
{"id":"plg-1","name":"unity","display_name":"Unity Format","version":"1.0.0",
 "status":"enabled","plugin_type":"format","config_schema":{},
 "installed_at":"2026-06-23T00:00:00Z"}
"""

@Suite("Plugin Path Tests")
struct PluginPathTests {

    @Test func listPluginsHitsPluginsPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, #"{"items":[]}"#)
        }

        let _: PluginListResponse = try await mock.client.request("/api/v1/plugins")

        #expect(log.contains(method: "GET", path: "/api/v1/plugins"))
    }

    @Test func getPluginHitsPluginIdPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, pluginJSON)
        }

        // Exercise the real APIClient.getPlugin(id:) so this pins the method's
        // path derivation, not a hand-built URL.
        let _: Plugin = try await mock.client.getPlugin(id: "plg-1")

        #expect(log.contains(method: "GET", path: "/api/v1/plugins/plg-1"))
    }

    @Test func enablePluginHitsEnablePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, "")
        }

        try await mock.client.requestVoid("/api/v1/plugins/plg-1/enable", method: "POST")

        #expect(log.contains(method: "POST", path: "/api/v1/plugins/plg-1/enable"))
    }

    @Test func disablePluginHitsDisablePath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, "")
        }

        try await mock.client.requestVoid("/api/v1/plugins/plg-1/disable", method: "POST")

        #expect(log.contains(method: "POST", path: "/api/v1/plugins/plg-1/disable"))
    }

    @Test func reloadPluginHitsReloadPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, pluginJSON)
        }

        let _: Plugin = try await mock.client.request(
            "/api/v1/plugins/plg-1/reload",
            method: "POST"
        )

        #expect(log.contains(method: "POST", path: "/api/v1/plugins/plg-1/reload"))
    }

    // The two tests below drive the real production methods (not a hand-built
    // request) so the path/method assertions guard the actual install/uninstall
    // call sites used by PluginsView.

    @Test func installFromGitHitsGitInstallPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, """
            {"plugin_id":"plg-9","name":"Unity Format","version":"1.2.0",
             "format_key":"unity","message":"installed"}
            """)
        }

        let result = try await mock.client.installPluginFromGit(
            url: "https://github.com/example/unity-plugin.git",
            ref: "v1.2.0"
        )

        #expect(log.contains(method: "POST", path: "/api/v1/plugins/install/git"))
        #expect(result.pluginId == "plg-9")
        #expect(result.formatKey == "unity")
    }

    @Test func uninstallPluginHitsPluginByIdPath() async throws {
        let mock = MockSession(baseURL: "https://test-api.example.com")
        let log = PluginCallLog()
        mock.handler = { request in
            log.add(request.httpMethod ?? "", request.url!.path)
            return pluginOk(request.url!, "")
        }

        try await mock.client.uninstallPlugin(id: "plg-7")

        #expect(log.contains(method: "DELETE", path: "/api/v1/plugins/plg-7"))
    }
}

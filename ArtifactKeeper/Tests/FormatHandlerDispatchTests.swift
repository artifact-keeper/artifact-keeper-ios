import Testing
import Foundation
import ArtifactKeeperClient
@testable import ArtifactKeeper

// Path-pinning tests for the SDK-backed format handler methods on APIClient.
// Each test drives the real production method through a RecordingTransport
// (defined in SecurityDispatchTests.swift, same target) with a runtime format
// key and asserts the request path, method, and operation id. A canned body lets
// the array case decode; single-object cases use `try?` since the empty object
// is recorded before it fails to decode.

@Suite("Format Handler SDK Dispatch Tests")
struct FormatHandlerDispatchTests {

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

    private func path(_ p: String?) -> String {
        guard let p else { return "" }
        return String(p.split(separator: "?", maxSplits: 1)[0])
    }

    @Test func listFormatHandlersHitsFormatsPath() async throws {
        let (api, transport) = await makeClient()

        _ = try await api.listFormatHandlers()

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/formats")
        #expect(rec?.operationID == "list_format_handlers")
    }

    @Test func getFormatHandlerHitsFormatByKeyPath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.getFormatHandler(formatKey: "maven")

        let rec = transport.last
        #expect(rec?.method == "GET")
        #expect(path(rec?.path) == "/api/v1/formats/maven")
        #expect(rec?.operationID == "get_format_handler")
    }

    @Test func enableFormatHandlerHitsEnablePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.enableFormatHandler(formatKey: "npm")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/formats/npm/enable")
        #expect(rec?.operationID == "enable_format_handler")
    }

    @Test func disableFormatHandlerHitsDisablePath() async throws {
        let (api, transport) = await makeClient()

        _ = try? await api.disableFormatHandler(formatKey: "npm")

        let rec = transport.last
        #expect(rec?.method == "POST")
        #expect(path(rec?.path) == "/api/v1/formats/npm/disable")
        #expect(rec?.operationID == "disable_format_handler")
    }
}

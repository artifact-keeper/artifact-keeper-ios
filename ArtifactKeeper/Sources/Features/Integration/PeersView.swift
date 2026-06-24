import SwiftUI

struct PeersView: View {
    @State private var peers: [Peer] = []
    @State private var identity: PeerIdentity?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingRegisterPeer = false

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading peers...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Peers Unavailable",
                    systemImage: "network.slash",
                    description: Text(error)
                )
            } else {
                VStack(spacing: 0) {
                    if peers.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No Peers",
                            systemImage: "network",
                            description: Text("No peer instances registered yet.")
                        )
                        Spacer()
                    } else {
                        List {
                            if let identity {
                                Section("This Instance") {
                                    LabeledContent("Name", value: identity.name)
                                    LabeledContent("Peer ID", value: identity.peerId)
                                    LabeledContent("Endpoint", value: identity.endpointUrl)
                                        .lineLimit(1)
                                }
                            }

                            Section("Peers") {
                                ForEach(peers) { peer in
                                    NavigationLink {
                                        PeerDetailView(listPeer: peer)
                                    } label: {
                                        PeerRow(peer: peer)
                                    }
                                }
                                .onDelete { indexSet in
                                    Task {
                                        for index in indexSet {
                                            await deletePeer(peers[index])
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }

                    Divider()
                    HStack(spacing: 16) {
                        Button {
                            showingRegisterPeer = true
                        } label: {
                            Label("Register Peer", systemImage: "plus.circle")
                                .font(.body.weight(.medium))
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await loadPeers() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.body.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .refreshable { await loadPeers() }
        .task { await loadPeers() }
        .sheet(isPresented: $showingRegisterPeer) {
            NavigationStack {
                RegisterPeerView { await loadPeers() }
                    .navigationTitle("Register Peer")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    private func loadPeers() async {
        isLoading = peers.isEmpty
        do {
            let response: PeerListResponse = try await apiClient.request("/api/v1/peers")
            peers = response.items
            errorMessage = nil
        } catch {
            if peers.isEmpty {
                errorMessage = "Could not load peers. This feature may not be available on your server."
            }
        }
        // Identity is best-effort: a failure here should not blank the peer list.
        identity = try? await apiClient.getPeerIdentity()
        isLoading = false
    }

    private func deletePeer(_ peer: Peer) async {
        do {
            try await apiClient.requestVoid(
                "/api/v1/peers/\(peer.id)",
                method: "DELETE"
            )
            peers.removeAll { $0.id == peer.id }
        } catch {
            // silent
        }
    }
}

struct PeerRow: View {
    let peer: Peer

    var statusColor: Color {
        switch peer.status {
        case "online": return .green
        case "offline": return .red
        case "syncing": return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(peer.name)
                    .font(.body.weight(.medium))
                if peer.isLocal {
                    Text("Local")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(peer.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(statusColor)
            }
            Text(peer.endpointUrl)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 12) {
                if let region = peer.region {
                    Label(region, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if peer.cacheSizeBytes > 0 {
                    Text("Cache: \(Int(peer.cacheUsagePercent))%")
                        .font(.caption)
                        .foregroundStyle(peer.cacheUsagePercent > 90 ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Register Peer Sheet

private struct RegisterPeerBody: Encodable {
    let name: String
    let endpoint_url: String
    let region: String?
    let api_key: String
}

struct RegisterPeerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var endpointUrl = ""
    @State private var region = ""
    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared
    var onSaved: () async -> Void

    var body: some View {
        Form {
            Section("Peer Info") {
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
                TextField("https://peer.example.com", text: $endpointUrl)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                TextField("Region (optional)", text: $region)
                    .autocorrectionDisabled()
            }

            Section {
                SecureField("API Key", text: $apiKey)
                    .autocorrectionDisabled()
            } header: {
                Text("Authentication")
            } footer: {
                Text("The API key used to authenticate with this peer instance.")
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Register") { Task { await registerPeer() } }
                    .disabled(isSaving || name.isEmpty || endpointUrl.isEmpty || apiKey.isEmpty)
            }
        }
    }

    private func registerPeer() async {
        isSaving = true
        errorMessage = nil

        let trimmedURL = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://") else {
            errorMessage = "URL must start with http:// or https://"
            isSaving = false
            return
        }

        do {
            let body = RegisterPeerBody(
                name: name.trimmingCharacters(in: .whitespaces),
                endpoint_url: trimmedURL,
                region: region.isEmpty ? nil : region.trimmingCharacters(in: .whitespaces),
                api_key: apiKey
            )
            let _: Peer = try await apiClient.request(
                "/api/v1/peers",
                method: "POST",
                body: body
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = "Failed to register peer: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

// MARK: - Peer Detail

/// Peer detail with a freshly fetched record (GET /api/v1/peers/{id}) and the
/// peer's connection list (GET /api/v1/peers/{id}/connections).
struct PeerDetailView: View {
    let listPeer: Peer

    @State private var fetched: Peer?
    @State private var connections: [PeerConnection] = []
    @State private var loadError: String?

    private let apiClient = APIClient.shared

    /// Freshest peer: the by-id fetch if it succeeded, else the list value.
    private var peer: Peer { fetched ?? listPeer }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Peer") {
                LabeledContent("Name", value: peer.name)
                LabeledContent("Status", value: peer.status.capitalized)
                LabeledContent("Endpoint", value: peer.endpointUrl).lineLimit(1)
                if let region = peer.region, !region.isEmpty {
                    LabeledContent("Region", value: region)
                }
                LabeledContent("Cache", value: "\(Int(peer.cacheUsagePercent))% used")
            }

            Section("Lifecycle") {
                if let heartbeat = peer.lastHeartbeatAt, !heartbeat.isEmpty {
                    LabeledContent("Last Heartbeat", value: heartbeat)
                }
                if let sync = peer.lastSyncAt, !sync.isEmpty {
                    LabeledContent("Last Sync", value: sync)
                }
                LabeledContent("Registered", value: peer.createdAt)
            }

            Section("Connections (\(connections.count))") {
                if connections.isEmpty {
                    Text("No connections recorded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(connections) { connection in
                        PeerConnectionRow(connection: connection)
                    }
                }
            }
        }
        .navigationTitle(peer.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            fetched = try await apiClient.getPeer(id: listPeer.id)
            loadError = nil
        } catch {
            loadError = "Showing cached details; could not refresh: \(error.localizedDescription)"
        }
        // Connections are best-effort and shown separately from the peer record.
        connections = (try? await apiClient.listPeerConnections(id: listPeer.id)) ?? []
    }
}

struct PeerConnectionRow: View {
    let connection: PeerConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(connection.targetPeerId)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(connection.status.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let latency = connection.latencyMs {
                    Label("\(latency) ms", systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Label("\(connection.sharedArtifactsCount) artifacts", systemImage: "shippingbox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

import SwiftUI

struct ReplicationView: View {
    @State private var selectedTab = "overview"
    @State private var peers: [Peer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Overview").tag("overview")
                Text("Subscriptions").tag("subscriptions")
                Text("Topology").tag("topology")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if isLoading {
                Spacer()
                ProgressView("Loading peers...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ContentUnavailableView(
                    "Replication Unavailable",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text(error)
                )
                Spacer()
            } else if peers.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Peers",
                    systemImage: "network",
                    description: Text("Register peers from the Peers tab to see replication status here.")
                )
                Spacer()
            } else {
                switch selectedTab {
                case "overview":
                    ReplicationOverviewTab(peers: peers)
                case "subscriptions":
                    ReplicationSubscriptionsTab(peers: peers)
                case "topology":
                    ReplicationTopologyTab(peers: peers)
                default:
                    EmptyView()
                }
            }
        }
        .refreshable { await loadPeers() }
        .task { await loadPeers() }
    }

    private func loadPeers() async {
        isLoading = peers.isEmpty
        do {
            let response: PeerListResponse = try await apiClient.request("/api/v1/peers")
            peers = response.items
            errorMessage = nil
        } catch {
            if peers.isEmpty {
                errorMessage = "Could not load peers."
            }
        }
        isLoading = false
    }
}

// MARK: - Overview Tab

private struct ReplicationOverviewTab: View {
    let peers: [Peer]

    var onlineCount: Int { peers.filter { $0.status == "online" }.count }
    var syncingCount: Int { peers.filter { $0.status == "syncing" }.count }

    var totalCache: Int64 { peers.reduce(0) { $0 + $1.cacheSizeBytes } }
    var usedCache: Int64 { peers.reduce(0) { $0 + $1.cacheUsedBytes } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stats cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ReplicationStatCard(title: "Total Peers", value: "\(peers.count)", icon: "server.rack", color: .blue)
                    ReplicationStatCard(title: "Online", value: "\(onlineCount)", icon: "checkmark.circle", color: .green)
                    ReplicationStatCard(title: "Syncing", value: "\(syncingCount)", icon: "arrow.triangle.2.circlepath", color: .orange)
                    ReplicationStatCard(title: "Cache Usage", value: formatCacheUsage(), icon: "internaldrive", color: .purple)
                }
                .padding(.horizontal)

                // Peer cards
                ForEach(peers) { peer in
                    PeerOverviewCard(peer: peer)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func formatCacheUsage() -> String {
        guard totalCache > 0 else { return "0%" }
        let pct = Double(usedCache) / Double(totalCache) * 100
        return "\(Int(pct))%"
    }
}

private struct ReplicationStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PeerOverviewCard: View {
    let peer: Peer

    var statusColor: Color {
        switch peer.status {
        case "online": return .green
        case "offline": return .red
        case "syncing": return .orange
        case "degraded": return .yellow
        default: return .secondary
        }
    }

    var cachePercent: Double { peer.cacheUsagePercent }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(peer.name)
                    .font(.body.weight(.semibold))
                if peer.isLocal {
                    Text("Local")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(peer.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            Text(peer.endpointUrl)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let region = peer.region, !region.isEmpty {
                Label(region, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Cache bar
            if peer.cacheSizeBytes > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Cache")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatBytes(peer.cacheUsedBytes)) / \(formatBytes(peer.cacheSizeBytes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.fill.tertiary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cachePercent > 90 ? .red : .blue)
                                .frame(width: geo.size.width * min(cachePercent / 100, 1.0))
                        }
                    }
                    .frame(height: 6)
                }
            }

            HStack(spacing: 16) {
                if let sync = peer.lastSyncAt {
                    Label(formatRelative(sync), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let hb = peer.lastHeartbeatAt {
                    Label(formatRelative(hb), systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Subscriptions Tab

private struct ReplicationSubscriptionsTab: View {
    let peers: [Peer]
    @State private var selectedPeerId: String?
    @State private var assignedRepoIds: [String] = []
    @State private var repositories: [Repository] = []
    @State private var isLoading = false

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            // Peer picker
            HStack {
                Text("Peer:")
                    .font(.subheadline.weight(.medium))
                Picker("Select Peer", selection: $selectedPeerId) {
                    Text("Select a peer").tag(String?.none)
                    ForEach(peers) { peer in
                        Text(peer.name).tag(Optional(peer.id))
                    }
                }
                .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedPeerId == nil {
                Spacer()
                ContentUnavailableView(
                    "Select a Peer",
                    systemImage: "server.rack",
                    description: Text("Choose a peer to view its repository subscriptions.")
                )
                Spacer()
            } else if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if repositories.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "folder",
                    description: Text("No repositories available to assign.")
                )
                Spacer()
            } else {
                List(repositories) { repo in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(repo.key)
                                .font(.body.weight(.medium))
                            Text(repo.format)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.indigo.opacity(0.1), in: Capsule())
                                .foregroundStyle(.indigo)
                        }
                        Spacer()
                        if assignedRepoIds.contains(repo.id) {
                            Text("Assigned")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.1), in: Capsule())
                                .foregroundStyle(.green)
                        } else {
                            Button("Assign") {
                                Task { await assignRepo(repo) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: selectedPeerId) { _, newValue in
            if newValue != nil {
                Task { await loadSubscriptions() }
            }
        }
    }

    private func loadSubscriptions() async {
        guard let peerId = selectedPeerId else { return }
        isLoading = true
        do {
            async let reposResult: RepositoryListResponse = apiClient.request("/api/v1/repositories?per_page=200")
            async let assignedResult: [String] = apiClient.request("/api/v1/peers/\(peerId)/repositories")
            let (repos, assigned) = try await (reposResult, assignedResult)
            repositories = repos.items
            assignedRepoIds = assigned
        } catch {
            // silent
        }
        isLoading = false
    }

    private func assignRepo(_ repo: Repository) async {
        guard let peerId = selectedPeerId else { return }
        do {
            let body = AssignRepoBody(repository_id: repo.id, replication_mode: "pull")
            try await apiClient.requestVoid(
                "/api/v1/peers/\(peerId)/repositories",
                method: "POST",
                body: body
            )
            assignedRepoIds.append(repo.id)
        } catch {
            // silent
        }
    }
}

private struct AssignRepoBody: Encodable {
    let repository_id: String
    let replication_mode: String
}

// MARK: - Topology Tab

private struct ReplicationTopologyTab: View {
    let peers: [Peer]
    @State private var selectedPeerId: String?
    @State private var connections: [PeerConnection] = []
    @State private var isLoading = false

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            // Peer picker
            HStack {
                Text("Peer:")
                    .font(.subheadline.weight(.medium))
                Picker("Select Peer", selection: $selectedPeerId) {
                    Text("Select a peer").tag(String?.none)
                    ForEach(peers) { peer in
                        Text(peer.name).tag(Optional(peer.id))
                    }
                }
                .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if selectedPeerId == nil {
                Spacer()
                ContentUnavailableView(
                    "Select a Peer",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Choose a peer to view its network connections.")
                )
                Spacer()
            } else if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if connections.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Connections",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("This peer has no active connections to other peers.")
                )
                Spacer()
            } else {
                List(connections) { conn in
                    ConnectionRow(connection: conn, peers: peers)
                }
                .listStyle(.plain)
            }
        }
        .onChange(of: selectedPeerId) { _, newValue in
            if newValue != nil {
                Task { await loadConnections() }
            }
        }
    }

    private func loadConnections() async {
        guard let peerId = selectedPeerId else { return }
        isLoading = true
        do {
            connections = try await apiClient.request("/api/v1/peers/\(peerId)/connections")
        } catch {
            connections = []
        }
        isLoading = false
    }
}

private struct ConnectionRow: View {
    let connection: PeerConnection
    let peers: [Peer]

    var targetName: String {
        peers.first { $0.id == connection.targetPeerId }?.name ?? connection.targetPeerId
    }

    var statusColor: Color {
        connection.status == "connected" ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(targetName)
                    .font(.body.weight(.medium))
                Spacer()
                Text(connection.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 16) {
                if let latency = connection.latencyMs {
                    Label("\(latency)ms", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let bw = connection.bandwidthEstimateBps {
                    Label(formatBandwidth(bw), systemImage: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label("\(connection.sharedArtifactsCount) shared", systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(formatBytes(connection.bytesTransferredTotal), systemImage: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text("\(connection.transferSuccessCount)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.green.opacity(0.1), in: Capsule())
                        .foregroundStyle(.green)
                    if connection.transferFailureCount > 0 {
                        Text("\(connection.transferFailureCount)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.red.opacity(0.1), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shared Helpers

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: bytes)
}

private func formatBandwidth(_ bps: Int64) -> String {
    if bps >= 1_000_000_000 { return String(format: "%.1f Gbps", Double(bps) / 1e9) }
    if bps >= 1_000_000 { return String(format: "%.1f Mbps", Double(bps) / 1e6) }
    if bps >= 1_000 { return String(format: "%.1f Kbps", Double(bps) / 1e3) }
    return "\(bps) bps"
}

private func formatRelative(_ isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: isoString) ?? {
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }()
    guard let date else { return isoString }
    let relative = RelativeDateTimeFormatter()
    relative.unitsStyle = .abbreviated
    return relative.localizedString(for: date, relativeTo: Date())
}

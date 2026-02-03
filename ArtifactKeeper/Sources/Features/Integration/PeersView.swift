import SwiftUI

struct PeersView: View {
    @State private var peers: [Peer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
            } else if peers.isEmpty {
                ContentUnavailableView(
                    "No Peers",
                    systemImage: "network",
                    description: Text("No peer instances configured. Add peers from the web interface to enable federation.")
                )
            } else {
                List(peers) { peer in
                    PeerRow(peer: peer)
                }
                .listStyle(.plain)
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
                errorMessage = "Could not load peers. This feature may not be available on your server."
            }
        }
        isLoading = false
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
                Spacer()
                Text(peer.status.capitalized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.1), in: Capsule())
                    .foregroundStyle(statusColor)
            }
            Text(peer.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

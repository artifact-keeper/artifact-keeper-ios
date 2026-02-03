import SwiftUI

struct IntegrationSectionView: View {
    @State private var selectedTab = "peers"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Peers").tag("peers")
                    Text("Replication").tag("replication")
                    Text("Webhooks").tag("webhooks")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch selectedTab {
                    case "peers":
                        PeersView()
                    case "replication":
                        ReplicationView()
                    case "webhooks":
                        WebhooksView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Integration")
            .accountToolbar()
        }
    }
}

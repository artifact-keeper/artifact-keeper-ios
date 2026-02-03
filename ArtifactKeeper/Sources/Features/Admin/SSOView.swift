import SwiftUI

struct SSOView: View {
    @State private var providers: [SSOProvider] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading SSO providers...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "SSO Unavailable",
                    systemImage: "key.slash",
                    description: Text(error)
                )
            } else if providers.isEmpty {
                ContentUnavailableView(
                    "No SSO Providers",
                    systemImage: "key.horizontal",
                    description: Text("Configure SSO providers from the web interface to enable single sign-on.")
                )
            } else {
                List(providers) { provider in
                    SSOProviderRow(provider: provider)
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadProviders() }
        .task { await loadProviders() }
    }

    private func loadProviders() async {
        isLoading = providers.isEmpty
        do {
            let response: SSOProviderListResponse = try await apiClient.request("/api/v1/admin/sso/providers")
            providers = response.items
            errorMessage = nil
        } catch {
            if providers.isEmpty {
                errorMessage = "Could not load SSO providers. You may need admin privileges."
            }
        }
        isLoading = false
    }
}

struct SSOProviderRow: View {
    let provider: SSOProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(provider.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(provider.providerType.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.indigo.opacity(0.1), in: Capsule())
                    .foregroundStyle(.indigo)
            }
            HStack {
                if provider.enabled {
                    Label("Enabled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Disabled", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let issuer = provider.issuerUrl {
                    Text(issuer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

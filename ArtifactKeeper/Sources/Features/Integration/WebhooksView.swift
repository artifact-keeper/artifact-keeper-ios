import SwiftUI

struct WebhooksView: View {
    @State private var webhooks: [Webhook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading webhooks...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Webhooks Unavailable",
                    systemImage: "link.badge.plus",
                    description: Text(error)
                )
            } else if webhooks.isEmpty {
                ContentUnavailableView(
                    "No Webhooks",
                    systemImage: "link",
                    description: Text("Configure webhooks from the web interface to receive notifications about artifact events.")
                )
            } else {
                List(webhooks) { webhook in
                    WebhookRow(webhook: webhook)
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadWebhooks() }
        .task { await loadWebhooks() }
    }

    private func loadWebhooks() async {
        isLoading = webhooks.isEmpty
        do {
            let response: WebhookListResponse = try await apiClient.request("/api/v1/webhooks")
            webhooks = response.items
            errorMessage = nil
        } catch {
            if webhooks.isEmpty {
                errorMessage = "Could not load webhooks. This feature may not be available on your server."
            }
        }
        isLoading = false
    }
}

struct WebhookRow: View {
    let webhook: Webhook

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(webhook.name)
                    .font(.body.weight(.medium))
                Spacer()
                if webhook.enabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            Text(webhook.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 4) {
                ForEach(webhook.events, id: \.self) { event in
                    Text(event)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

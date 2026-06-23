import SwiftUI

struct WebhooksView: View {
    @State private var webhooks: [Webhook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddWebhook = false
    @State private var testingWebhookId: String?
    @State private var testResult: (success: Bool, message: String)?
    // Newly rotated secret to show once (it is not retrievable later).
    @State private var rotatedSecret: RotateWebhookSecretResponse?

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
            } else {
                VStack(spacing: 0) {
                    if webhooks.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No Webhooks",
                            systemImage: "link",
                            description: Text("No webhooks configured yet.")
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(webhooks) { webhook in
                                WebhookRow(
                                    webhook: webhook,
                                    isTesting: testingWebhookId == webhook.id,
                                    onToggle: { await toggleWebhook(webhook) },
                                    onTest: { await testWebhook(webhook) },
                                    onRotateSecret: { await rotateSecret(webhook) },
                                    onDelete: { await deleteWebhook(webhook) }
                                )
                            }

                            if let result = testResult {
                                Section {
                                    HStack(spacing: 8) {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(result.success ? .green : .red)
                                        Text(result.message)
                                            .font(.caption)
                                            .foregroundStyle(result.success ? .green : .red)
                                        Spacer()
                                        Button { testResult = nil } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }

                    Divider()
                    Button {
                        showingAddWebhook = true
                    } label: {
                        Label("Add Webhook", systemImage: "plus.circle")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 16)
                }
            }
        }
        .refreshable { await loadWebhooks() }
        .task { await loadWebhooks() }
        .sheet(isPresented: $showingAddWebhook) {
            NavigationStack {
                AddWebhookView { await loadWebhooks() }
                    .navigationTitle("Add Webhook")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
        .sheet(item: $rotatedSecret) { secret in
            NavigationStack {
                RotatedSecretView(secret: secret)
            }
        }
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

    private func toggleWebhook(_ webhook: Webhook) async {
        let action = webhook.isEnabled ? "disable" : "enable"
        do {
            try await apiClient.requestVoid(
                "/api/v1/webhooks/\(webhook.id)/\(action)",
                method: "POST"
            )
            await loadWebhooks()
        } catch {
            testResult = (success: false, message: "Failed to \(action) webhook: \(error.localizedDescription)")
        }
    }

    private func testWebhook(_ webhook: Webhook) async {
        testingWebhookId = webhook.id
        testResult = nil
        do {
            let response: TestWebhookResponse = try await apiClient.request(
                "/api/v1/webhooks/\(webhook.id)/test",
                method: "POST"
            )
            if response.success {
                testResult = (success: true, message: "Test delivered — HTTP \(response.statusCode ?? 0)")
            } else {
                testResult = (success: false, message: response.error ?? "Test delivery failed (HTTP \(response.statusCode ?? 0))")
            }
        } catch {
            testResult = (success: false, message: "Test failed: \(error.localizedDescription)")
        }
        testingWebhookId = nil
    }

    private func rotateSecret(_ webhook: Webhook) async {
        do {
            let response: RotateWebhookSecretResponse = try await apiClient.request(
                "/api/v1/webhooks/\(webhook.id)/rotate-secret",
                method: "POST"
            )
            rotatedSecret = response
        } catch {
            testResult = (success: false, message: "Failed to rotate secret: \(error.localizedDescription)")
        }
    }

    private func deleteWebhook(_ webhook: Webhook) async {
        do {
            try await apiClient.requestVoid(
                "/api/v1/webhooks/\(webhook.id)",
                method: "DELETE"
            )
            webhooks.removeAll { $0.id == webhook.id }
        } catch {
            testResult = (success: false, message: "Failed to delete: \(error.localizedDescription)")
        }
    }
}

struct WebhookRow: View {
    let webhook: Webhook
    let isTesting: Bool
    let onToggle: () async -> Void
    let onTest: () async -> Void
    let onRotateSecret: () async -> Void
    let onDelete: () async -> Void

    @State private var showingDeleteConfirm = false
    @State private var showingRotateConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(webhook.name)
                    .font(.body.weight(.medium))
                Spacer()
                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await onToggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(webhook.isEnabled ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Text(webhook.isEnabled ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundStyle(webhook.isEnabled ? .green : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(webhook.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(webhook.events, id: \.self) { event in
                        Text(event.replacingOccurrences(of: "_", with: " "))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }

            NavigationLink {
                WebhookDeliveriesView(webhook: webhook)
            } label: {
                Label("Delivery History", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await onTest() }
            } label: {
                Label("Test", systemImage: "paperplane")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button { Task { await onToggle() } } label: {
                Label(webhook.isEnabled ? "Disable" : "Enable",
                      systemImage: webhook.isEnabled ? "pause.circle" : "play.circle")
            }
            Button { Task { await onTest() } } label: {
                Label("Send Test", systemImage: "paperplane")
            }
            Button { showingRotateConfirm = true } label: {
                Label("Rotate Secret", systemImage: "key.horizontal")
            }
            Divider()
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Webhook", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await onDelete() } }
        } message: {
            Text("Delete \"\(webhook.name)\"? This cannot be undone.")
        }
        .alert("Rotate Signing Secret", isPresented: $showingRotateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Rotate") { Task { await onRotateSecret() } }
        } message: {
            Text("Generate a new signing secret for \"\(webhook.name)\"? The current secret keeps working for a short grace period.")
        }
    }
}

// MARK: - Add Webhook Sheet

private let allWebhookEvents = [
    "artifact_uploaded",
    "artifact_deleted",
    "repository_created",
    "repository_deleted",
    "user_created",
    "user_deleted",
    "build_started",
    "build_completed",
    "build_failed",
]

private struct CreateWebhookBody: Encodable {
    let name: String
    let url: String
    let events: [String]
    let secret: String?
}

struct AddWebhookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var secret = ""
    @State private var selectedEvents: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared
    var onSaved: () async -> Void

    var body: some View {
        Form {
            Section("Webhook Info") {
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
                TextField("https://example.com/webhook", text: $url)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
            }

            Section {
                SecureField("Signing secret (optional)", text: $secret)
                    .autocorrectionDisabled()
            } header: {
                Text("Secret")
            } footer: {
                Text("If provided, deliveries will include an HMAC-SHA256 signature header for verification.")
            }

            Section("Events") {
                ForEach(allWebhookEvents, id: \.self) { event in
                    Button {
                        if selectedEvents.contains(event) {
                            selectedEvents.remove(event)
                        } else {
                            selectedEvents.insert(event)
                        }
                    } label: {
                        HStack {
                            Text(event.replacingOccurrences(of: "_", with: " ").capitalized)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedEvents.contains(event) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Button {
                    if selectedEvents.count == allWebhookEvents.count {
                        selectedEvents.removeAll()
                    } else {
                        selectedEvents = Set(allWebhookEvents)
                    }
                } label: {
                    Text(selectedEvents.count == allWebhookEvents.count ? "Deselect All" : "Select All")
                        .font(.caption)
                }
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
                Button("Create") { Task { await createWebhook() } }
                    .disabled(isSaving || name.isEmpty || url.isEmpty || selectedEvents.isEmpty)
            }
        }
    }

    private func createWebhook() async {
        isSaving = true
        errorMessage = nil

        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://") else {
            errorMessage = "URL must start with http:// or https://"
            isSaving = false
            return
        }

        do {
            let body = CreateWebhookBody(
                name: name.trimmingCharacters(in: .whitespaces),
                url: trimmedURL,
                events: Array(selectedEvents),
                secret: secret.isEmpty ? nil : secret
            )
            let _: Webhook = try await apiClient.request(
                "/api/v1/webhooks",
                method: "POST",
                body: body
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = "Failed to create webhook: \(error.localizedDescription)"
        }
        isSaving = false
    }
}

// MARK: - Rotated Secret Sheet

/// Shows a freshly rotated signing secret once. The plaintext secret is not
/// retrievable after this sheet is dismissed.
struct RotatedSecretView: View {
    let secret: RotateWebhookSecretResponse

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Text(secret.secret)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            } header: {
                Text("New Signing Secret")
            } footer: {
                Text("Copy this now. It will not be shown again. The previous secret keeps working until \(secret.previousSecretExpiresAt).")
            }
        }
        .navigationTitle("Secret Rotated")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Webhook Delivery History

/// Lists recent delivery attempts for a webhook and allows redelivering one.
struct WebhookDeliveriesView: View {
    let webhook: Webhook

    @State private var deliveries: [WebhookDelivery] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var redeliveringId: String?
    @State private var actionMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading deliveries...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Deliveries Unavailable",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text(error)
                )
            } else if deliveries.isEmpty {
                ContentUnavailableView(
                    "No Deliveries",
                    systemImage: "clock",
                    description: Text("This webhook has not delivered any events yet.")
                )
            } else {
                List {
                    if let actionMessage {
                        Section {
                            Text(actionMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(deliveries) { delivery in
                        DeliveryRow(
                            delivery: delivery,
                            isRedelivering: redeliveringId == delivery.id,
                            onRedeliver: { await redeliver(delivery) }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Deliveries")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await loadDeliveries() }
        .task { await loadDeliveries() }
    }

    private func loadDeliveries() async {
        isLoading = deliveries.isEmpty
        do {
            let response: WebhookDeliveryListResponse = try await apiClient.request(
                "/api/v1/webhooks/\(webhook.id)/deliveries"
            )
            deliveries = response.items
            errorMessage = nil
        } catch {
            if deliveries.isEmpty {
                errorMessage = "Could not load delivery history."
            }
        }
        isLoading = false
    }

    private func redeliver(_ delivery: WebhookDelivery) async {
        redeliveringId = delivery.id
        defer { redeliveringId = nil }
        do {
            let _: WebhookDelivery = try await apiClient.request(
                "/api/v1/webhooks/\(webhook.id)/deliveries/\(delivery.id)/redeliver",
                method: "POST"
            )
            actionMessage = "Redelivery queued for \(delivery.event)."
            await loadDeliveries()
        } catch {
            actionMessage = "Redelivery failed: \(error.localizedDescription)"
        }
    }
}

struct DeliveryRow: View {
    let delivery: WebhookDelivery
    let isRedelivering: Bool
    let onRedeliver: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: delivery.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(delivery.success ? .green : .red)
                    .font(.caption)
                Text(delivery.event.replacingOccurrences(of: "_", with: " "))
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let status = delivery.responseStatus {
                    Text("HTTP \(status)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Text(delivery.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if delivery.attempts > 1 {
                    Text("\(delivery.attempts) attempts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            Button {
                Task { await onRedeliver() }
            } label: {
                Label("Redeliver", systemImage: "arrow.clockwise")
            }
            .tint(.blue)
            .disabled(isRedelivering)
        }
        .contextMenu {
            Button { Task { await onRedeliver() } } label: {
                Label("Redeliver", systemImage: "arrow.clockwise")
            }
        }
    }
}

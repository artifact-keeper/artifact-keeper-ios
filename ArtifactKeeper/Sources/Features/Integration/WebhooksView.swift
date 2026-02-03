import SwiftUI

struct WebhooksView: View {
    @State private var webhooks: [Webhook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddWebhook = false
    @State private var testingWebhookId: String?
    @State private var testResult: (success: Bool, message: String)?

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
    let onDelete: () async -> Void

    @State private var showingDeleteConfirm = false

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

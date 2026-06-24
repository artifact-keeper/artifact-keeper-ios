import SwiftUI

/// Lists the registered format handlers (GET /api/v1/formats) and lets an
/// operator inspect one (GET /api/v1/formats/{format_key}) and enable or disable
/// it (POST .../enable | .../disable).
struct FormatsView: View {
    @State private var handlers: [FormatHandler] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var mutatingKey: String?
    @State private var actionMessage: (success: Bool, text: String)?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading format handlers\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Formats Unavailable", systemImage: "shippingbox")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if handlers.isEmpty {
                ContentUnavailableView(
                    "No Format Handlers",
                    systemImage: "shippingbox",
                    description: Text("No format handlers are registered.")
                )
            } else {
                List {
                    if let actionMessage {
                        Section {
                            HStack(spacing: 8) {
                                Image(systemName: actionMessage.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(actionMessage.success ? .green : .red)
                                Text(actionMessage.text)
                                    .font(.caption)
                                    .foregroundStyle(actionMessage.success ? .green : .red)
                            }
                        }
                    }
                    ForEach(handlers) { handler in
                        NavigationLink {
                            FormatHandlerDetailView(
                                listHandler: handler,
                                isMutating: mutatingKey == handler.formatKey,
                                onToggle: { await toggle(handler) }
                            )
                        } label: {
                            FormatHandlerRow(handler: handler)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = handlers.isEmpty
        do {
            handlers = try await apiClient.listFormatHandlers()
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            errorMessage = nil
        } catch {
            if handlers.isEmpty {
                errorMessage = "Could not load format handlers. This feature may not be available on your server."
            }
        }
        isLoading = false
    }

    private func toggle(_ handler: FormatHandler) async {
        mutatingKey = handler.formatKey
        defer { mutatingKey = nil }
        do {
            if handler.isEnabled {
                _ = try await apiClient.disableFormatHandler(formatKey: handler.formatKey)
                actionMessage = (true, "\(handler.displayName) disabled.")
            } else {
                _ = try await apiClient.enableFormatHandler(formatKey: handler.formatKey)
                actionMessage = (true, "\(handler.displayName) enabled.")
            }
            await load()
        } catch {
            actionMessage = (false, "Failed to update \(handler.displayName): \(error.localizedDescription)")
        }
    }
}

private struct FormatHandlerRow: View {
    let handler: FormatHandler

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: handler.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(handler.isEnabled ? Color.green : Color.secondary)
                Text(handler.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(handler.handlerType)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(handler.handlerType == "Wasm" ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(handler.handlerType == "Wasm" ? .purple : .blue)
            }
            HStack(spacing: 8) {
                Text(handler.formatKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let count = handler.repositoryCount {
                    Text("\u{00B7} \(count) repo\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Detail for one format handler. Re-fetches by key on appear so a stale list
/// value is refreshed, and offers an enable/disable toggle.
struct FormatHandlerDetailView: View {
    let listHandler: FormatHandler
    let isMutating: Bool
    let onToggle: () async -> Void

    @State private var fetched: FormatHandler?
    @State private var loadError: String?

    private let apiClient = APIClient.shared

    private var handler: FormatHandler { fetched ?? listHandler }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Handler") {
                detailRow("Name", handler.displayName)
                detailRow("Format", handler.formatKey)
                detailRow("Type", handler.handlerType)
                detailRow("Status", handler.isEnabled ? "Enabled" : "Disabled")
                detailRow("Priority", "\(handler.priority)")
                if let count = handler.repositoryCount {
                    detailRow("Repositories", "\(count)")
                }
            }

            if let description = handler.description, !description.isEmpty {
                Section("Description") {
                    Text(description).font(.subheadline)
                }
            }

            if !handler.extensions.isEmpty {
                Section("Extensions") {
                    Text(handler.extensions.joined(separator: ", "))
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    Task { await onToggle() }
                } label: {
                    Label(handler.isEnabled ? "Disable" : "Enable",
                          systemImage: handler.isEnabled ? "pause.circle" : "play.circle")
                }
                .disabled(isMutating)
            }
        }
        .navigationTitle(handler.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
    }

    private func loadDetail() async {
        do {
            fetched = try await apiClient.getFormatHandler(formatKey: listHandler.formatKey)
            loadError = nil
        } catch {
            loadError = "Showing cached details; could not refresh: \(error.localizedDescription)"
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

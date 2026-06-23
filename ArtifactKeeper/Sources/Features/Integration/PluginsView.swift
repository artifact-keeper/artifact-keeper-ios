import SwiftUI

/// Lists installed WASM format plugins and supports enable/disable/reload.
/// Installation (upload/git/local/zip), uninstall and config authoring are
/// deferred: they are deep-authoring/upload flows better suited to the web UI.
struct PluginsView: View {
    @State private var plugins: [Plugin] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var mutatingPluginId: String?
    @State private var actionMessage: (success: Bool, text: String)?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading plugins...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Plugins Unavailable",
                    systemImage: "puzzlepiece.extension",
                    description: Text(error)
                )
            } else if plugins.isEmpty {
                ContentUnavailableView(
                    "No Plugins",
                    systemImage: "puzzlepiece",
                    description: Text("No format plugins are installed.")
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
                    ForEach(plugins) { plugin in
                        NavigationLink {
                            PluginDetailView(
                                plugin: plugin,
                                isMutating: mutatingPluginId == plugin.id,
                                onToggle: { await toggle(plugin) },
                                onReload: { await reload(plugin) }
                            )
                        } label: {
                            PluginRow(plugin: plugin)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { await loadPlugins() }
        .task { await loadPlugins() }
    }

    private func loadPlugins() async {
        isLoading = plugins.isEmpty
        do {
            let response: PluginListResponse = try await apiClient.request("/api/v1/plugins")
            plugins = response.items
            errorMessage = nil
        } catch {
            if plugins.isEmpty {
                errorMessage = "Could not load plugins. This feature may not be available on your server."
            }
        }
        isLoading = false
    }

    private func toggle(_ plugin: Plugin) async {
        let action = plugin.isEnabled ? "disable" : "enable"
        mutatingPluginId = plugin.id
        defer { mutatingPluginId = nil }
        do {
            try await apiClient.requestVoid(
                "/api/v1/plugins/\(plugin.id)/\(action)",
                method: "POST"
            )
            actionMessage = (true, "\(plugin.displayName) \(action)d.")
            await loadPlugins()
        } catch {
            actionMessage = (false, "Failed to \(action) \(plugin.displayName): \(error.localizedDescription)")
        }
    }

    private func reload(_ plugin: Plugin) async {
        mutatingPluginId = plugin.id
        defer { mutatingPluginId = nil }
        do {
            let _: Plugin = try await apiClient.request(
                "/api/v1/plugins/\(plugin.id)/reload",
                method: "POST"
            )
            actionMessage = (true, "\(plugin.displayName) reloaded.")
            await loadPlugins()
        } catch {
            actionMessage = (false, "Failed to reload \(plugin.displayName): \(error.localizedDescription)")
        }
    }
}

struct PluginRow: View {
    let plugin: Plugin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(plugin.displayName)
                    .font(.body.weight(.medium))
                Text("v\(plugin.version)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(plugin.isEnabled ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(plugin.status.capitalized)
                        .font(.caption)
                        .foregroundStyle(plugin.isEnabled ? .green : .secondary)
                }
            }
            HStack(spacing: 6) {
                Text(plugin.pluginType)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
                if let description = plugin.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Plugin Detail

struct PluginDetailView: View {
    let plugin: Plugin
    let isMutating: Bool
    let onToggle: () async -> Void
    let onReload: () async -> Void

    var body: some View {
        List {
            Section("Plugin") {
                detailRow("Name", plugin.displayName)
                detailRow("Identifier", plugin.name)
                detailRow("Version", plugin.version)
                detailRow("Type", plugin.pluginType)
                detailRow("Status", plugin.status.capitalized)
                if let author = plugin.author, !author.isEmpty {
                    detailRow("Author", author)
                }
                if let homepage = plugin.homepage, !homepage.isEmpty {
                    detailRow("Homepage", homepage)
                }
            }

            if let description = plugin.description, !description.isEmpty {
                Section("Description") {
                    Text(description)
                        .font(.subheadline)
                }
            }

            Section("Lifecycle") {
                detailRow("Installed", plugin.installedAt)
                if let enabledAt = plugin.enabledAt, !enabledAt.isEmpty {
                    detailRow("Enabled", enabledAt)
                }
            }

            Section {
                Button {
                    Task { await onToggle() }
                } label: {
                    Label(plugin.isEnabled ? "Disable" : "Enable",
                          systemImage: plugin.isEnabled ? "pause.circle" : "play.circle")
                }
                .disabled(isMutating)

                Button {
                    Task { await onReload() }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(isMutating)
            }
        }
        .navigationTitle(plugin.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

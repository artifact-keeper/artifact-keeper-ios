import SwiftUI

struct MonitoringView: View {
    @State private var health: SystemHealth?
    @State private var storage: StorageInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading system status...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Monitoring Unavailable",
                    systemImage: "heart.slash",
                    description: Text(error)
                )
            } else {
                List {
                    if let health = health {
                        Section("System Health") {
                            LabeledContent("Status") {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(health.status == "ok" || health.status == "healthy" ? .green : .red)
                                        .frame(width: 8, height: 8)
                                    Text(health.status.capitalized)
                                }
                            }
                            if let version = health.version {
                                LabeledContent("Version", value: version)
                            }
                            if let uptime = health.uptime {
                                LabeledContent("Uptime", value: uptime)
                            }
                        }

                        if let db = health.database {
                            Section("Database") {
                                LabeledContent("Status") {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(db.status == "ok" || db.status == "healthy" ? .green : .red)
                                            .frame(width: 8, height: 8)
                                        Text(db.status.capitalized)
                                    }
                                }
                                if let msg = db.message {
                                    LabeledContent("Info", value: msg)
                                }
                            }
                        }

                        if let stor = health.storage {
                            Section("Storage Service") {
                                LabeledContent("Status") {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(stor.status == "ok" || stor.status == "healthy" ? .green : .red)
                                            .frame(width: 8, height: 8)
                                        Text(stor.status.capitalized)
                                    }
                                }
                                if let msg = stor.message {
                                    LabeledContent("Info", value: msg)
                                }
                            }
                        }
                    }

                    if let storage = storage {
                        Section("Disk Usage") {
                            LabeledContent("Total", value: formatBytes(storage.totalBytes))
                            LabeledContent("Used", value: formatBytes(storage.usedBytes))
                            LabeledContent("Available", value: formatBytes(storage.availableBytes))
                            if storage.totalBytes > 0 {
                                let pct = Double(storage.usedBytes) / Double(storage.totalBytes)
                                ProgressView(value: pct) {
                                    Text("\(Int(pct * 100))% used")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tint(pct > 0.9 ? .red : pct > 0.7 ? .orange : .green)
                            }
                        }
                    }
                }
            }
        }
        .refreshable { await loadData() }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = health == nil
        var gotData = false

        do {
            health = try await apiClient.request("/api/v1/system/health")
            gotData = true
        } catch {
            // health endpoint may not exist
        }

        do {
            storage = try await apiClient.request("/api/v1/system/storage")
            gotData = true
        } catch {
            // storage endpoint may not exist
        }

        if !gotData && health == nil {
            errorMessage = "Could not load system status. This feature may not be available on your server."
        } else {
            errorMessage = nil
        }

        isLoading = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

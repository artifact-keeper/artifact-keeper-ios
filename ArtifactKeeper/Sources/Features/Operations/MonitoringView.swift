import SwiftUI

struct MonitoringView: View {
    @State private var health: HealthResponse?
    @State private var healthLog: [HealthLogEntry] = []
    @State private var alerts: [AlertState] = []
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
                                StatusDot(status: health.status)
                            }
                            if let version = health.version {
                                LabeledContent("Version", value: version)
                            }
                        }

                        if let checks = health.checks, !checks.isEmpty {
                            Section("Services") {
                                ForEach(checks.sorted(by: { $0.key < $1.key }), id: \.key) { name, check in
                                    LabeledContent(name.capitalized) {
                                        StatusDot(status: check.status)
                                    }
                                }
                            }
                        }
                    }

                    if !alerts.isEmpty {
                        Section("Alerts") {
                            ForEach(alerts) { alert in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(alert.serviceName.capitalized)
                                            .font(.body.weight(.medium))
                                        Spacer()
                                        StatusDot(status: alert.currentStatus)
                                    }
                                    if alert.consecutiveFailures > 0 {
                                        Text("\(alert.consecutiveFailures) consecutive failures")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                    }

                    if !healthLog.isEmpty {
                        Section("Recent Health Checks") {
                            ForEach(healthLog.prefix(20)) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.serviceName.capitalized)
                                            .font(.body.weight(.medium))
                                        Spacer()
                                        StatusDot(status: entry.status)
                                    }
                                    HStack(spacing: 12) {
                                        Text("\(entry.responseTimeMs)ms")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let msg = entry.message {
                                            Text(msg)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(formatDate(entry.checkedAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
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
            health = try await apiClient.request("/health")
            gotData = true
        } catch {}

        do {
            alerts = try await apiClient.request("/api/v1/admin/monitoring/alerts")
            gotData = true
        } catch {}

        do {
            healthLog = try await apiClient.request("/api/v1/admin/monitoring/health-log?limit=20")
            gotData = true
        } catch {}

        if !gotData {
            errorMessage = "Could not load monitoring data."
        } else {
            errorMessage = nil
        }
        isLoading = false
    }

    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoString) {
            let relative = RelativeDateTimeFormatter()
            relative.unitsStyle = .abbreviated
            return relative.localizedString(for: date, relativeTo: Date())
        }
        return isoString
    }
}

struct StatusDot: View {
    let status: String

    var color: Color {
        switch status {
        case "healthy", "ok": return .green
        case "degraded", "warning": return .orange
        case "unhealthy", "critical": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.capitalized)
                .font(.caption)
        }
    }
}

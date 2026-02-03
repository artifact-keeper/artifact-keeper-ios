import SwiftUI

struct TelemetryView: View {
    @State private var metrics: TelemetryMetrics?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading telemetry...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Telemetry Unavailable",
                    systemImage: "waveform.slash",
                    description: Text(error)
                )
            } else if let metrics = metrics {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 16) {
                        if let rpm = metrics.requestsPerMinute {
                            MetricCard(title: "Requests/min", value: String(format: "%.1f", rpm), icon: "arrow.up.arrow.down", color: .blue)
                        }
                        if let errRate = metrics.errorRate {
                            MetricCard(title: "Error Rate", value: String(format: "%.2f%%", errRate * 100), icon: "exclamationmark.triangle", color: errRate > 0.05 ? .red : .green)
                        }
                        if let latency = metrics.avgLatencyMs {
                            MetricCard(title: "Avg Latency", value: String(format: "%.0fms", latency), icon: "clock", color: latency > 500 ? .orange : .green)
                        }
                        if let conns = metrics.activeConnections {
                            MetricCard(title: "Connections", value: "\(conns)", icon: "personalhotspot", color: .purple)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Telemetry Data",
                    systemImage: "waveform",
                    description: Text("No telemetry data available yet.")
                )
            }
        }
        .refreshable { await loadMetrics() }
        .task { await loadMetrics() }
    }

    private func loadMetrics() async {
        isLoading = metrics == nil
        do {
            metrics = try await apiClient.request("/api/v1/telemetry/metrics")
            errorMessage = nil
        } catch {
            if metrics == nil {
                errorMessage = "Could not load telemetry data. This feature may not be available on your server."
            }
        }
        isLoading = false
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

import SwiftUI

struct TelemetryView: View {
    @State private var metrics: [MetricLine] = []
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
            } else if metrics.isEmpty {
                ContentUnavailableView(
                    "No Telemetry Data",
                    systemImage: "waveform",
                    description: Text("No metrics data available yet.")
                )
            } else {
                List {
                    Section("HTTP Requests") {
                        ForEach(requestMetrics) { metric in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.labels["path"] ?? "unknown")
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)
                                    Text(metric.labels["method"] ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(metric.value))")
                                    .font(.title3.bold().monospacedDigit())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    if !latencyMetrics.isEmpty {
                        Section("Response Times") {
                            ForEach(latencyMetrics) { metric in
                                HStack {
                                    Text(metric.labels["path"] ?? metric.name)
                                        .font(.body)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1fms", metric.value))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !otherMetrics.isEmpty {
                        Section("Other Metrics") {
                            ForEach(otherMetrics) { metric in
                                HStack {
                                    Text(metric.displayName)
                                        .font(.body)
                                    Spacer()
                                    Text(metric.formattedValue)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable { await loadMetrics() }
        .task { await loadMetrics() }
    }

    private var requestMetrics: [MetricLine] {
        metrics
            .filter { $0.name == "ak_http_requests_total" }
            .sorted { $0.value > $1.value }
    }

    private var latencyMetrics: [MetricLine] {
        metrics.filter { $0.name.contains("duration") || $0.name.contains("latency") }
    }

    private var otherMetrics: [MetricLine] {
        metrics.filter {
            $0.name != "ak_http_requests_total" &&
            !$0.name.contains("duration") &&
            !$0.name.contains("latency")
        }
    }

    private func loadMetrics() async {
        isLoading = metrics.isEmpty
        do {
            let url = await apiClient.buildURL("/metrics")
            guard let url = url else {
                errorMessage = "Could not build metrics URL."
                isLoading = false
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(data: data, encoding: .utf8) ?? ""
            metrics = parsePrometheusMetrics(text)
            errorMessage = nil
        } catch {
            if metrics.isEmpty {
                errorMessage = "Could not load telemetry data."
            }
        }
        isLoading = false
    }

    private func parsePrometheusMetrics(_ text: String) -> [MetricLine] {
        var result: [MetricLine] = []
        for line in text.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("#") { continue }
            guard let parsed = parseMetricLine(s) else { continue }
            result.append(parsed)
        }
        return result
    }

    private func parseMetricLine(_ line: String) -> MetricLine? {
        // Format: metric_name{label="value",label2="value2"} 123
        // or:     metric_name 123
        let parts: [String]
        var name: String
        var labels: [String: String] = [:]

        if let braceStart = line.firstIndex(of: "{"),
           let braceEnd = line.firstIndex(of: "}") {
            name = String(line[line.startIndex..<braceStart])
            let labelStr = String(line[line.index(after: braceStart)..<braceEnd])
            for pair in labelStr.split(separator: ",") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0])
                    let val = String(kv[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    labels[key] = val
                }
            }
            let remainder = String(line[line.index(after: braceEnd)...]).trimmingCharacters(in: .whitespaces)
            parts = [name, remainder]
        } else {
            parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            name = parts.first ?? ""
        }

        guard parts.count >= 2, let value = Double(parts.last ?? "") else { return nil }

        return MetricLine(name: name, labels: labels, value: value)
    }
}

struct MetricLine: Identifiable {
    let name: String
    let labels: [String: String]
    let value: Double

    var id: String {
        let labelStr = labels.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(name){\(labelStr)}"
    }

    var displayName: String {
        if labels.isEmpty {
            return name.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "\(name) [\(labels.values.joined(separator: ", "))]"
    }

    var formattedValue: String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }
}

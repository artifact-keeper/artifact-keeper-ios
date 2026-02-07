import SwiftUI
import Charts

// MARK: - Aggregated Metrics Point

struct AggregatedMetricsPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let critical: Int64
    let high: Int64
    let medium: Int64
    let low: Int64

    var total: Int64 { critical + high + medium + low }
}

// MARK: - Main Dashboard View

struct DtDashboardView: View {
    let status: DtStatus
    let metrics: DtPortfolioMetrics?
    let projects: [DtProject]
    let metricsHistory: [String: [DtProjectMetrics]]

    private var aggregatedHistory: [AggregatedMetricsPoint] {
        var dateMap: [Date: (Int64, Int64, Int64, Int64)] = [:]

        for (_, history) in metricsHistory {
            for point in history {
                guard let epoch = point.lastOccurrence else { continue }
                let date = Calendar.current.startOfDay(
                    for: Date(timeIntervalSince1970: TimeInterval(epoch) / 1000)
                )
                let existing = dateMap[date] ?? (0, 0, 0, 0)
                dateMap[date] = (
                    existing.0 + point.critical,
                    existing.1 + point.high,
                    existing.2 + point.medium,
                    existing.3 + point.low
                )
            }
        }

        return dateMap
            .map { AggregatedMetricsPoint(date: $0.key, critical: $0.value.0, high: $0.value.1, medium: $0.value.2, low: $0.value.3) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with status badge
            DtStatusHeader(status: status)

            if let m = metrics {
                // Summary Cards
                DtSummaryCardsSection(
                    metrics: m,
                    projects: projects,
                    history: aggregatedHistory
                )

                // Severity Distribution
                DtSeverityDistributionView(metrics: m)

                // Progress Bars
                DtProgressBarsSection(metrics: m)

                // Risk Score Gauge
                DtRiskScoreGaugeView(riskScore: m.inheritedRiskScore)

                // Portfolio Trend Chart
                if !aggregatedHistory.isEmpty {
                    DtPortfolioTrendChartView(history: aggregatedHistory)
                }
            } else if !status.healthy {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Unable to reach Dependency-Track server")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Status Header

private struct DtStatusHeader: View {
    let status: DtStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.title3)
                .foregroundStyle(.indigo)

            Text("Dependency-Track")
                .font(.headline)

            Spacer()

            Text(status.healthy ? "Connected" : "Disconnected")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (status.healthy ? Color.green : Color.red).opacity(0.15),
                    in: Capsule()
                )
                .foregroundStyle(status.healthy ? .green : .red)
        }
    }
}

// MARK: - Summary Cards with Sparklines

private struct DtSummaryCardsSection: View {
    let metrics: DtPortfolioMetrics
    let projects: [DtProject]
    let history: [AggregatedMetricsPoint]

    private var totalVulnerabilities: Int64 {
        metrics.critical + metrics.high + metrics.medium + metrics.low
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            DtSparklineCard(
                title: "Portfolio Vulnerabilities",
                value: totalVulnerabilities,
                color: .red,
                sparklineData: history.map { Double($0.total) }
            )

            DtSparklineCard(
                title: "Projects at Risk",
                value: Int64(projects.count),
                color: .purple,
                sparklineData: history.map { Double($0.critical + $0.high) }
            )

            DtSparklineCard(
                title: "Vulnerable Components",
                value: metrics.vulnerabilities ?? 0,
                color: .green,
                sparklineData: history.map { Double($0.medium + $0.low) }
            )

            DtSparklineCard(
                title: "Inherited Risk Score",
                value: Int64(metrics.inheritedRiskScore),
                color: riskScoreColor(metrics.inheritedRiskScore),
                sparklineData: [] // Risk score is a snapshot, no per-point data
            )
        }
    }

    private func riskScoreColor(_ score: Double) -> Color {
        if score >= 70 { return .red }
        if score >= 40 { return .orange }
        if score >= 10 { return .yellow }
        return .green
    }
}

private struct DtSparklineCard: View {
    let title: String
    let value: Int64
    let color: Color
    let sparklineData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(value)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(value > 0 ? color : .secondary)

                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if sparklineData.count > 2 {
                    Chart {
                        ForEach(Array(sparklineData.enumerated()), id: \.offset) { index, val in
                            LineMark(
                                x: .value("Index", index),
                                y: .value("Value", val)
                            )
                            .foregroundStyle(color)

                            AreaMark(
                                x: .value("Index", index),
                                y: .value("Value", val)
                            )
                            .foregroundStyle(color.opacity(0.1))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(width: 64, height: 32)
                }
            }
        }
        .padding(12)
        .background(color.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Severity Distribution

struct DtSeverityDistributionView: View {
    let metrics: DtPortfolioMetrics

    private var total: Int64 {
        metrics.critical + metrics.high + metrics.medium + metrics.low
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Severity Distribution")
                .font(.subheadline.weight(.semibold))

            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        severitySegment(count: metrics.critical, color: .red, width: geo.size.width)
                        severitySegment(count: metrics.high, color: .orange, width: geo.size.width)
                        severitySegment(count: metrics.medium, color: .yellow, width: geo.size.width)
                        severitySegment(count: metrics.low, color: .blue, width: geo.size.width)
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 20)

                // Legend
                HStack(spacing: 16) {
                    severityLegendItem(label: "Critical", count: metrics.critical, color: .red)
                    severityLegendItem(label: "High", count: metrics.high, color: .orange)
                    severityLegendItem(label: "Medium", count: metrics.medium, color: .yellow)
                    severityLegendItem(label: "Low", count: metrics.low, color: .blue)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.green)
                    Text("No vulnerabilities detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func severitySegment(count: Int64, color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: total > 0 ? width * CGFloat(count) / CGFloat(total) : 0)
    }

    private func severityLegendItem(label: String, count: Int64, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Progress Bars

private struct DtProgressBarsSection: View {
    let metrics: DtPortfolioMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audit & Compliance")
                .font(.subheadline.weight(.semibold))

            DtProgressRow(
                label: "Findings Audited",
                current: metrics.findingsAudited,
                total: metrics.findingsTotal,
                color: .green
            )

            DtProgressRow(
                label: "Policy Violations",
                current: metrics.policyViolationsFail,
                total: metrics.policyViolationsTotal,
                color: .red,
                labelSuffix: "failures"
            )

            DtProgressRow(
                label: "Suppressions",
                current: metrics.suppressions,
                total: metrics.findingsTotal,
                color: .purple
            )
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DtProgressRow: View {
    let label: String
    let current: Int64
    let total: Int64
    let color: Color
    var labelSuffix: String? = nil

    private var fraction: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(current) / \(total)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                if let suffix = labelSuffix {
                    Text(suffix)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Risk Score Gauge

struct DtRiskScoreGaugeView: View {
    let riskScore: Double

    private var normalizedScore: Double {
        min(riskScore / 100.0, 1.0)
    }

    private var gaugeColor: Color {
        if riskScore >= 70 { return .red }
        if riskScore >= 40 { return .orange }
        if riskScore >= 10 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Inherited Risk Score")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                // Background arc
                GaugeArc(fraction: 1.0)
                    .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 90)

                // Foreground arc
                GaugeArc(fraction: normalizedScore)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 90)

                // Score text
                VStack(spacing: 0) {
                    Spacer()
                    Text(String(format: "%.0f", riskScore))
                        .font(.title.weight(.bold))
                        .foregroundStyle(gaugeColor)
                    Text("Risk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 90)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct GaugeArc: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2, rect.height)
        let startAngle = Angle(degrees: 180)
        let endAngle = Angle(degrees: 180 + 180 * fraction)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - Portfolio Trend Chart

struct DtPortfolioTrendChartView: View {
    let history: [AggregatedMetricsPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Portfolio Vulnerabilities")
                .font(.subheadline.weight(.semibold))

            if let first = history.first, let last = history.last {
                Text("Last \(Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(history) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.critical)
                    )
                    .foregroundStyle(by: .value("Severity", "Critical"))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.high)
                    )
                    .foregroundStyle(by: .value("Severity", "High"))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.medium)
                    )
                    .foregroundStyle(by: .value("Severity", "Medium"))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.low)
                    )
                    .foregroundStyle(by: .value("Severity", "Low"))
                }
            }
            .chartForegroundStyleScale([
                "Critical": Color.red,
                "High": Color.orange,
                "Medium": Color.yellow,
                "Low": Color.blue,
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

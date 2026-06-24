import SwiftUI

/// Quality health dashboard (GET /api/v1/quality/health/dashboard). Shows the
/// portfolio-wide averages and grade distribution, plus a per-repository health
/// breakdown.
struct HealthDashboardView: View {
    @State private var dashboard: HealthDashboard?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading health dashboard\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Dashboard Unavailable", systemImage: "heart.text.square")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if let dashboard {
                List {
                    Section("Overview") {
                        overviewRow("Repositories", "\(dashboard.totalRepositories)")
                        overviewRow("Artifacts Evaluated", "\(dashboard.totalArtifactsEvaluated)")
                        HStack {
                            Text("Average Health Score")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(dashboard.avgHealthScore)")
                                .font(.headline)
                        }
                        .font(.subheadline)
                    }

                    Section("Grade Distribution") {
                        gradeRow("A", dashboard.reposGradeA, .green)
                        gradeRow("B", dashboard.reposGradeB, .mint)
                        gradeRow("C", dashboard.reposGradeC, .yellow)
                        gradeRow("D", dashboard.reposGradeD, .orange)
                        gradeRow("F", dashboard.reposGradeF, .red)
                    }

                    if dashboard.repositories.isEmpty {
                        Section("Repositories") {
                            Text("No repositories have been evaluated yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Repositories") {
                            ForEach(dashboard.repositories) { repo in
                                RepoHealthRow(repo: repo)
                            }
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
        isLoading = dashboard == nil
        do {
            dashboard = try await apiClient.getHealthDashboard()
            errorMessage = nil
        } catch {
            if dashboard == nil {
                errorMessage = "Could not load the health dashboard. You may need admin privileges."
            }
        }
        isLoading = false
    }

    private func overviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func gradeRow(_ grade: String, _ count: Int, _ color: Color) -> some View {
        HStack {
            Text("Grade \(grade)")
                .foregroundStyle(color)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
        }
        .font(.subheadline)
    }
}

private struct RepoHealthRow: View {
    let repo: RepoHealth

    var body: some View {
        HStack(spacing: 12) {
            GradeBadge(grade: repo.healthGrade)
            VStack(alignment: .leading, spacing: 4) {
                Text(repo.repositoryKey)
                    .font(.headline)
                    .lineLimit(1)
                Text("Score \(repo.healthScore) \u{00B7} \(repo.artifactsPassing)/\(repo.artifactsEvaluated) passing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

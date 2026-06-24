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

                    Section("Artifact Health") {
                        NavigationLink {
                            ArtifactHealthLookupView()
                        } label: {
                            Label("Look up artifact health", systemImage: "magnifyingglass")
                        }
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
                                NavigationLink {
                                    RepoHealthDetailView(repoKey: repo.repositoryKey, listRepo: repo)
                                } label: {
                                    RepoHealthRow(repo: repo)
                                }
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

/// Detail for one repository's health. Re-fetches by key on appear
/// (GET /api/v1/quality/health/repositories/{key}) so a stale dashboard value is
/// refreshed and the per-component average scores are shown.
private struct RepoHealthDetailView: View {
    let repoKey: String
    let listRepo: RepoHealth

    @State private var fetched: RepoHealth?
    @State private var loadError: String?

    private let apiClient = APIClient.shared

    private var repo: RepoHealth { fetched ?? listRepo }

    var body: some View {
        List {
            if let loadError {
                Section {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack(spacing: 12) {
                    GradeBadge(grade: repo.healthGrade)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.repositoryKey).font(.headline)
                        Text("Health score \(repo.healthScore)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Artifacts") {
                detailRow("Evaluated", "\(repo.artifactsEvaluated)")
                detailRow("Passing", "\(repo.artifactsPassing)")
                detailRow("Failing", "\(repo.artifactsFailing)")
            }

            Section("Average Scores") {
                scoreRow("Security", repo.avgSecurityScore)
                scoreRow("Quality", repo.avgQualityScore)
                scoreRow("Metadata", repo.avgMetadataScore)
                scoreRow("License", repo.avgLicenseScore)
            }
        }
        .navigationTitle(repo.repositoryKey)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
    }

    private func loadDetail() async {
        do {
            fetched = try await apiClient.getRepoHealth(repoKey: repoKey)
            loadError = nil
        } catch {
            loadError = "Showing cached health; could not refresh: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func scoreRow(_ label: String, _ value: Int?) -> some View {
        if let value {
            detailRow(label, "\(value)")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

/// Look up a single artifact's health by id
/// (GET /api/v1/quality/health/artifacts/{artifact_id}).
private struct ArtifactHealthLookupView: View {
    @State private var artifactId = ""
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var health: ArtifactHealth?
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        Form {
            Section("Artifact") {
                TextField("Artifact id", text: $artifactId)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
                    .onSubmit { Task { await lookup() } }
                Button {
                    Task { await lookup() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Look Up Health")
                    }
                }
                .disabled(artifactId.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } else if !hasSearched {
                Section {
                    Text("Enter an artifact id to see its health score and check breakdown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let health {
                Section {
                    HStack(spacing: 12) {
                        GradeBadge(grade: health.healthGrade)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health score \(health.healthScore)").font(.headline)
                            Text("\(health.checksPassed)/\(health.checksTotal) checks passed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Issues") {
                    detailRow("Total Issues", "\(health.totalIssues)")
                    detailRow("Critical Issues", "\(health.criticalIssues)")
                }

                Section("Component Scores") {
                    scoreRow("Security", health.securityScore)
                    scoreRow("Quality", health.qualityScore)
                    scoreRow("Metadata", health.metadataScore)
                    scoreRow("License", health.licenseScore)
                }

                if !health.checks.isEmpty {
                    Section("Checks") {
                        ForEach(health.checks) { check in
                            HStack {
                                Image(systemName: checkIcon(check))
                                    .foregroundStyle(checkColor(check))
                                Text(check.checkType.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                if let score = check.score {
                                    Text("\(score)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(check.status.capitalized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(checkColor(check))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Artifact Health")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func lookup() async {
        let trimmed = artifactId.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }
        do {
            health = try await apiClient.getArtifactHealth(artifactId: trimmed)
        } catch {
            health = nil
            errorMessage = "Could not load artifact health: \(error.localizedDescription)"
        }
    }

    private func checkIcon(_ check: CheckSummary) -> String {
        if let passed = check.passed {
            return passed ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        return "circle"
    }

    private func checkColor(_ check: CheckSummary) -> Color {
        if let passed = check.passed {
            return passed ? .green : .red
        }
        return .secondary
    }

    @ViewBuilder
    private func scoreRow(_ label: String, _ value: Int?) -> some View {
        if let value {
            detailRow(label, "\(value)")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

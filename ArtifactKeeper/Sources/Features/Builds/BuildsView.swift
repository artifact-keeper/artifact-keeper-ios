import SwiftUI

struct BuildsView: View {
    @State private var builds: [BuildItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var statusFilter = "all"

    private let apiClient = APIClient.shared

    private let statusOptions = ["all", "success", "failed", "running", "pending"]

    var filteredBuilds: [BuildItem] {
        var result = builds

        if statusFilter != "all" {
            result = result.filter { $0.status == statusFilter }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.vcsBranch?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.vcsMessage?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading builds...")
                } else if filteredBuilds.isEmpty {
                    if searchText.isEmpty && statusFilter == "all" {
                        ContentUnavailableView(
                            "No Builds",
                            systemImage: "hammer",
                            description: Text("No builds have been recorded yet.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    List(filteredBuilds) { build in
                        NavigationLink(value: build.id) {
                            BuildListItem(build: build)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Builds")
            .searchable(text: $searchText, prompt: "Search builds")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(statusOptions, id: \.self) { option in
                            Button {
                                statusFilter = option
                            } label: {
                                HStack {
                                    Text(option.capitalized)
                                    if statusFilter == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await loadBuilds()
            }
            .task {
                await loadBuilds()
            }
            .navigationDestination(for: String.self) { buildId in
                if let build = builds.first(where: { $0.id == buildId }) {
                    BuildDetailView(build: build)
                }
            }
        }
    }

    private func loadBuilds() async {
        isLoading = builds.isEmpty
        do {
            let response: BuildListResponse = try await apiClient.request(
                "/api/v1/builds?per_page=100&sort_by=created_at&sort_order=desc"
            )
            builds = response.items
        } catch {
            // silent for now
        }
        isLoading = false
    }
}

// MARK: - Build List Item

struct BuildListItem: View {
    let build: BuildItem

    var body: some View {
        HStack(spacing: 12) {
            buildStatusIcon(build.status)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(build.name) #\(build.number)")
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(buildStatusLabel(build.status))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(buildStatusColor(build.status).opacity(0.1), in: Capsule())
                        .foregroundStyle(buildStatusColor(build.status))
                }

                HStack(spacing: 12) {
                    if let branch = build.vcsBranch {
                        Label(branch, systemImage: "arrow.triangle.branch")
                    }
                    if let duration = build.durationMs {
                        Label(formatDuration(duration), systemImage: "clock")
                    }
                    Spacer()
                    Text(formatDate(build.createdAt))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Build Detail View

struct BuildDetailView: View {
    let build: BuildItem

    var body: some View {
        List {
            Section("Status") {
                HStack {
                    buildStatusIcon(build.status)
                    Text(buildStatusLabel(build.status))
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(buildStatusLabel(build.status))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(buildStatusColor(build.status).opacity(0.15), in: Capsule())
                        .foregroundStyle(buildStatusColor(build.status))
                }
            }

            Section("Build Info") {
                LabeledContent("Name", value: build.name)
                LabeledContent("Number", value: "#\(build.number)")
                if let agent = build.agent {
                    LabeledContent("Agent", value: agent)
                }
                if let count = build.artifactCount {
                    LabeledContent("Artifacts", value: "\(count)")
                }
            }

            Section("Timing") {
                if let duration = build.durationMs {
                    LabeledContent("Duration", value: formatDuration(duration))
                }
                if let started = build.startedAt {
                    LabeledContent("Started", value: formatDate(started))
                }
                if let finished = build.finishedAt {
                    LabeledContent("Finished", value: formatDate(finished))
                }
                LabeledContent("Created", value: formatDate(build.createdAt))
            }

            if build.vcsBranch != nil || build.vcsRevision != nil || build.vcsMessage != nil {
                Section("Version Control") {
                    if let branch = build.vcsBranch {
                        LabeledContent("Branch", value: branch)
                    }
                    if let revision = build.vcsRevision {
                        LabeledContent("Commit", value: String(revision.prefix(12)))
                    }
                    if let message = build.vcsMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(message)
                                .font(.body)
                        }
                    }
                    if let url = build.vcsUrl {
                        LabeledContent("Repository", value: url)
                            .lineLimit(1)
                    }
                }
            }
        }
        .navigationTitle("\(build.name) #\(build.number)")
    }
}

// MARK: - Build Helpers

@ViewBuilder
private func buildStatusIcon(_ status: String) -> some View {
    switch status {
    case "success":
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    case "failed", "failure":
        Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.red)
    case "running":
        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
            .foregroundStyle(.orange)
    case "pending":
        Image(systemName: "clock.circle.fill")
            .foregroundStyle(.gray)
    default:
        Image(systemName: "questionmark.circle.fill")
            .foregroundStyle(.secondary)
    }
}

private func buildStatusLabel(_ status: String) -> String {
    status.capitalized
}

private func buildStatusColor(_ status: String) -> Color {
    switch status {
    case "success": return .green
    case "failed", "failure": return .red
    case "running": return .orange
    case "pending": return .gray
    default: return .secondary
    }
}

private func formatDuration(_ ms: Int64) -> String {
    let totalSeconds = ms / 1000
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    } else {
        return "\(seconds)s"
    }
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

import SwiftUI

struct StagingSectionView: View {
    @State private var selectedTab = "repositories"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Repos").tag("repositories")
                    Text("Activity").tag("activity")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch selectedTab {
                    case "repositories":
                        StagingListContentView()
                    case "activity":
                        StagingActivityView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Staging")
            .accountToolbar()
        }
    }
}

// MARK: - Staging Activity View

struct StagingActivityView: View {
    @State private var allHistory: [PromotionHistoryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    // Group history by date
    var groupedHistory: [(String, [PromotionHistoryEntry])] {
        let grouped = Dictionary(grouping: allHistory) { entry in
            formatDateForGrouping(entry.promotedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading activity...")
            } else if let error = errorMessage, allHistory.isEmpty {
                ContentUnavailableView(
                    "Activity Unavailable",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(error)
                )
            } else if allHistory.isEmpty {
                ContentUnavailableView(
                    "No Recent Activity",
                    systemImage: "clock",
                    description: Text("No promotion activity across staging repositories yet.")
                )
            } else {
                List {
                    ForEach(groupedHistory, id: \.0) { dateString, entries in
                        Section {
                            ForEach(entries) { entry in
                                StagingActivityRow(entry: entry)
                            }
                        } header: {
                            Text(dateString)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable {
            await loadActivity()
        }
        .task {
            await loadActivity()
        }
    }

    private func loadActivity() async {
        isLoading = allHistory.isEmpty
        do {
            // First get all staging repos, then fetch history from each
            let repos = try await apiClient.listStagingRepos()

            var allEntries: [PromotionHistoryEntry] = []
            for repo in repos {
                do {
                    let history = try await apiClient.getPromotionHistory(repoKey: repo.key)
                    allEntries.append(contentsOf: history)
                } catch {
                    // Continue with other repos if one fails
                }
            }

            // Sort by promotion date, newest first
            allHistory = allEntries.sorted { $0.promotedAt > $1.promotedAt }
            errorMessage = nil
        } catch {
            if allHistory.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func formatDateForGrouping(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date: Date?
        date = isoFormatter.date(from: isoString)

        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }

        guard let parsedDate = date else {
            return isoString
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(parsedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(parsedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: parsedDate)
        }
    }
}

// MARK: - Staging Activity Row

struct StagingActivityRow: View {
    let entry: PromotionHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artifact info with timeline dot
            HStack(spacing: 12) {
                // Timeline indicator
                VStack(spacing: 0) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                }
                .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.artifactName)
                            .font(.body.weight(.medium))

                        if let version = entry.artifactVersion {
                            Text(version)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: Capsule())
                        }

                        if entry.wasForced {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    // Flow indicator
                    HStack(spacing: 4) {
                        Text(entry.sourceRepoKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.targetRepoKey)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }

                    // Metadata
                    HStack(spacing: 8) {
                        if let username = entry.promotedByUsername {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.caption2)
                                Text(username)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }

                        Text(formatTime(entry.promotedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Comment if present
            if let comment = entry.comment, !comment.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.caption2)
                    Text(comment)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date: Date?
        date = isoFormatter.date(from: isoString)

        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: isoString)
        }

        guard let parsedDate = date else {
            return isoString
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: parsedDate)
    }
}

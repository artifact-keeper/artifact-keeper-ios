import SwiftUI

struct PromotionHistoryView: View {
    let repoKey: String

    @State private var history: [PromotionHistoryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private let apiClient = APIClient.shared

    var filteredHistory: [PromotionHistoryEntry] {
        if searchText.isEmpty {
            return history
        }
        return history.filter {
            $0.artifactName.localizedCaseInsensitiveContains(searchText) ||
            ($0.artifactVersion?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.targetRepoKey.localizedCaseInsensitiveContains(searchText) ||
            ($0.promotedByUsername?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.comment?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    // Group history by date
    var groupedHistory: [(String, [PromotionHistoryEntry])] {
        let grouped = Dictionary(grouping: filteredHistory) { entry in
            formatDateForGrouping(entry.promotedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading history...")
            } else if let error = errorMessage, history.isEmpty {
                ContentUnavailableView(
                    "History Unavailable",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(error)
                )
            } else if history.isEmpty {
                ContentUnavailableView(
                    "No Promotion History",
                    systemImage: "clock",
                    description: Text("No artifacts have been promoted from this repository yet.")
                )
            } else if filteredHistory.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(groupedHistory, id: \.0) { dateString, entries in
                        Section {
                            ForEach(entries) { entry in
                                PromotionHistoryRow(entry: entry)
                            }
                        } header: {
                            Text(dateString)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search history")
        .refreshable {
            await loadHistory()
        }
        .task {
            await loadHistory()
        }
    }

    private func loadHistory() async {
        isLoading = history.isEmpty
        do {
            history = try await apiClient.getPromotionHistory(repoKey: repoKey)
            errorMessage = nil
        } catch {
            if history.isEmpty {
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

// MARK: - Promotion History Row

struct PromotionHistoryRow: View {
    let entry: PromotionHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artifact info
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
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
                            Text("FORCED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }

                    // Promotion path
                    HStack(spacing: 4) {
                        Text(entry.sourceRepoKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.targetRepoKey)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }

            // Promoted by and time
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

                Spacer()

                Text(formatPromotionTime(entry.promotedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Comment if present
            if let comment = entry.comment, !comment.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatPromotionTime(_ isoString: String) -> String {
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

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: parsedDate, relativeTo: Date())
    }
}

// MARK: - Standalone History View (for Navigation)

struct PromotionHistoryStandaloneView: View {
    let repoKey: String

    var body: some View {
        NavigationStack {
            PromotionHistoryView(repoKey: repoKey)
                .navigationTitle("Promotion History")
                .accountToolbar()
        }
    }
}

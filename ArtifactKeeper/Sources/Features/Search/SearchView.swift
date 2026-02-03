import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [PackageItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    private let apiClient = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty && results.isEmpty {
                    ContentUnavailableView(
                        "Search Packages",
                        systemImage: "magnifyingglass",
                        description: Text("Search across all repositories by name, format, or version")
                    )
                } else if isSearching {
                    ProgressView("Searching...")
                } else if results.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(results) { pkg in
                        NavigationLink {
                            PackageDetailView(package: pkg)
                        } label: {
                            SearchResultRow(package: pkg)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .accountToolbar()
            .searchable(text: $searchText, prompt: "Search packages...")
            .onChange(of: searchText) { _, newValue in
                // Cancel any pending search
                searchTask?.cancel()

                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    results = []
                    isSearching = false
                    errorMessage = nil
                    return
                }

                // Debounce 300ms
                searchTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))

                    guard !Task.isCancelled else { return }

                    await performSearch(query: newValue)
                }
            }
            .overlay(alignment: .bottom) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.85), in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        errorMessage = nil

        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: PackageListResponse = try await apiClient.request(
                "/api/v1/packages?search=\(encoded)&per_page=50"
            )

            guard !Task.isCancelled else { return }

            results = response.items
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            results = []
        }
        isSearching = false
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let package: PackageItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(package.name)
                    .font(.body.weight(.medium))

                Spacer()

                Text(package.format.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 12) {
                Label(package.version, systemImage: "tag")

                Label(package.repositoryKey, systemImage: "folder")

                Spacer()

                Text(formatBytes(package.sizeBytes))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

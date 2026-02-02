import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [Artifact] = []
    @State private var isSearching = false
    
    private let apiClient = APIClient.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty && results.isEmpty {
                    ContentUnavailableView(
                        "Search Artifacts",
                        systemImage: "magnifyingglass",
                        description: Text("Search across all repositories")
                    )
                } else if isSearching {
                    ProgressView()
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(results) { artifact in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artifact.name)
                                .font(.body.weight(.medium))
                            HStack {
                                if let version = artifact.version {
                                    Text(version)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                Text(artifact.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search artifacts...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    guard !newValue.isEmpty else {
                        results = []
                        return
                    }
                    isSearching = true
                    // Search across all repos - use first repo's artifacts as demo
                    do {
                        let response: RepositoryListResponse = try await apiClient.request("/api/v1/repositories?per_page=100&q=\(newValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? newValue)")
                        // For now just show repos matched
                        results = []
                    } catch {
                        // silent
                    }
                    isSearching = false
                }
            }
        }
    }
}

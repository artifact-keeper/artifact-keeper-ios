import SwiftUI

// Browse a repository's contents as a tree (GET /api/v1/tree). Directories push a
// nested RepositoryTreeView at their path; files are leaf rows. Raw file content
// (GET /api/v1/tree/content) is octet-stream and not wired here; downloading a file
// is handled by the artifact detail download action.
struct RepositoryTreeView: View {
    let repoKey: String
    let path: String
    let title: String

    @State private var nodes: [TreeNode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let api = APIClient.shared

    init(repoKey: String, path: String = "", title: String? = nil) {
        self.repoKey = repoKey
        self.path = path
        self.title = title ?? repoKey
    }

    var body: some View {
        content
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task { await load() }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && nodes.isEmpty {
            ProgressView("Loading\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, nodes.isEmpty {
            ContentUnavailableView {
                Label("Could Not Load Tree", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await load() } }
            }
        } else if nodes.isEmpty {
            ContentUnavailableView("Empty", systemImage: "folder", description: Text("This location has no contents."))
        } else {
            List(nodes) { node in
                row(for: node)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func row(for node: TreeNode) -> some View {
        if node.isDirectory {
            NavigationLink {
                RepositoryTreeView(repoKey: repoKey, path: node.path, title: node.name)
            } label: {
                TreeNodeRow(node: node)
            }
        } else {
            TreeNodeRow(node: node)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            nodes = try await api.getRepositoryTree(repoKey: repoKey, path: path)
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

private struct TreeNodeRow: View {
    let node: TreeNode

    var body: some View {
        HStack {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(node.isDirectory ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                if node.isDirectory {
                    if let count = node.childrenCount {
                        Text("\(count) item\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let size = node.sizeBytes {
                    Text(Self.formatBytes(size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

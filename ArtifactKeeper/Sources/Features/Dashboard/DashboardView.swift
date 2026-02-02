import SwiftUI

struct DashboardView: View {
    @State private var repos: [Repository] = []
    @State private var scores: [RepoSecurityScore] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading...")
                        .padding(.top, 60)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    VStack(spacing: 20) {
                        // Stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 16) {
                            StatCard(
                                title: "Repositories",
                                value: "\(repos.count)",
                                icon: "folder.fill",
                                color: .blue
                            )
                            StatCard(
                                title: "Security Scores",
                                value: "\(scores.count)",
                                icon: "shield.checkered",
                                color: .green
                            )
                            StatCard(
                                title: "Grade A",
                                value: "\(scores.filter { $0.grade == "A" }.count)",
                                icon: "checkmark.seal.fill",
                                color: .mint
                            )
                            StatCard(
                                title: "Critical Issues",
                                value: "\(scores.reduce(0) { $0 + $1.criticalCount })",
                                icon: "exclamationmark.triangle.fill",
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                        
                        // Recent repos
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Repositories")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(repos.prefix(10)) { repo in
                                RepoRow(repo: repo)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = repos.isEmpty
        errorMessage = nil
        
        do {
            async let repoResponse: RepositoryListResponse = apiClient.request("/api/v1/repositories?per_page=100")
            async let scoresResponse: [RepoSecurityScore] = apiClient.request("/api/v1/security/scores")
            
            let (repoResult, scoresResult) = try await (repoResponse, scoresResponse)
            repos = repoResult.items
            scores = scoresResult
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct RepoRow: View {
    let repo: Repository
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.body.weight(.medium))
                
                HStack(spacing: 8) {
                    Text(repo.format.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                    
                    Text(repo.repoType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatBytes(repo.storageUsedBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(repo.artifactCount)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

import SwiftUI

struct SecurityView: View {
    @State private var scores: [RepoSecurityScore] = []
    @State private var isLoading = true
    
    private let apiClient = APIClient.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading security data...")
                } else if scores.isEmpty {
                    ContentUnavailableView(
                        "No Security Data",
                        systemImage: "shield.slash",
                        description: Text("Enable scanning on repositories to see security scores")
                    )
                } else {
                    List(scores) { score in
                        HStack(spacing: 12) {
                            GradeBadge(grade: score.grade)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(score.repositoryId.prefix(8) + "...")
                                    .font(.body.weight(.medium))
                                
                                HStack(spacing: 8) {
                                    if score.criticalCount > 0 {
                                        SeverityPill(count: score.criticalCount, label: "C", color: .red)
                                    }
                                    if score.highCount > 0 {
                                        SeverityPill(count: score.highCount, label: "H", color: .orange)
                                    }
                                    if score.mediumCount > 0 {
                                        SeverityPill(count: score.mediumCount, label: "M", color: .yellow)
                                    }
                                    if score.lowCount > 0 {
                                        SeverityPill(count: score.lowCount, label: "L", color: .blue)
                                    }
                                    if score.criticalCount + score.highCount + score.mediumCount + score.lowCount == 0 {
                                        Text("Clean")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Text("Score: \(score.score)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Security")
            .refreshable {
                await loadScores()
            }
            .task {
                await loadScores()
            }
        }
    }
    
    private func loadScores() async {
        isLoading = scores.isEmpty
        do {
            scores = try await apiClient.request("/api/v1/security/scores")
        } catch {
            // silent
        }
        isLoading = false
    }
}

struct GradeBadge: View {
    let grade: String
    
    var color: Color {
        switch grade {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        case "F": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        Text(grade)
            .font(.title2.bold())
            .frame(width: 44, height: 44)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(color)
    }
}

struct SeverityPill: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        Text("\(count)\(label)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

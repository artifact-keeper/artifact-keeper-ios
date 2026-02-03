import SwiftUI

struct PackagesView: View {
    @State private var packages: [PackageItem] = []
    @State private var isLoading = true
    @State private var searchText = ""

    private let apiClient = APIClient.shared

    var filteredPackages: [PackageItem] {
        if searchText.isEmpty {
            return packages
        }
        return packages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.format.localizedCaseInsensitiveContains(searchText) ||
            $0.repositoryKey.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading packages...")
                } else if filteredPackages.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No Packages",
                            systemImage: "shippingbox",
                            description: Text("No packages have been published yet.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    List(filteredPackages) { pkg in
                        NavigationLink(value: pkg.id) {
                            PackageListItem(package: pkg)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Packages")
            .searchable(text: $searchText, prompt: "Search packages")
            .refreshable {
                await loadPackages()
            }
            .task {
                await loadPackages()
            }
            .navigationDestination(for: String.self) { packageId in
                if let pkg = packages.first(where: { $0.id == packageId }) {
                    PackageDetailView(package: pkg)
                }
            }
        }
    }

    private func loadPackages() async {
        isLoading = packages.isEmpty
        do {
            let response: PackageListResponse = try await apiClient.request(
                "/api/v1/packages?per_page=100"
            )
            packages = response.items
        } catch {
            // silent for now
        }
        isLoading = false
    }
}

// MARK: - Package List Item

struct PackageListItem: View {
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
                Label(formatBytes(package.sizeBytes), systemImage: "internaldrive")
                Spacer()
                Label("\(package.downloadCount)", systemImage: "arrow.down.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Package Detail View

struct PackageDetailView: View {
    let package: PackageItem
    @State private var versions: [PackageVersion] = []
    @State private var isLoadingVersions = true

    private let apiClient = APIClient.shared

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Format", value: package.format.uppercased())
                LabeledContent("Version", value: package.version)
                LabeledContent("Repository", value: package.repositoryKey)
                LabeledContent("Size", value: formatBytes(package.sizeBytes))
                LabeledContent("Downloads", value: "\(package.downloadCount)")
                if let desc = package.description {
                    LabeledContent("Description", value: desc)
                }
                LabeledContent("Created", value: formatDate(package.createdAt))
                LabeledContent("Updated", value: formatDate(package.updatedAt))
            }

            Section("Versions") {
                if isLoadingVersions {
                    ProgressView("Loading versions...")
                } else if versions.isEmpty {
                    Text("No version history available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(versions) { ver in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(ver.version)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text(formatBytes(ver.sizeBytes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 12) {
                                Label("\(ver.downloadCount)", systemImage: "arrow.down.circle")
                                Spacer()
                                Text(formatDate(ver.createdAt))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(package.name)
        .task {
            await loadVersions()
        }
    }

    private func loadVersions() async {
        do {
            let response: PackageVersionsResponse = try await apiClient.request(
                "/api/v1/packages/\(package.id)/versions"
            )
            versions = response.versions
        } catch {
            // silent for now
        }
        isLoadingVersions = false
    }
}

// MARK: - Formatting Helpers

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

private func formatDate(_ isoString: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: isoString) {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
    // Try without fractional seconds
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: isoString) {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
    return isoString
}

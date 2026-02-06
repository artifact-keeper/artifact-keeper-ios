import SwiftUI

struct SbomView: View {
    let artifactId: String
    let artifactName: String

    @State private var sboms: [SbomResponse] = []
    @State private var selectedFormat: SbomFormat = .cyclonedx
    @State private var components: [SbomComponent] = []
    @State private var cveHistory: [CveHistoryEntry] = []
    @State private var isLoading = true
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingRawJson = false
    @State private var rawJsonContent: String?

    private let apiClient = APIClient.shared

    private var currentSbom: SbomResponse? {
        sboms.first { $0.format.lowercased() == selectedFormat.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with format picker and actions
                headerSection

                if isLoading {
                    ProgressView("Loading SBOM...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else if let sbom = currentSbom {
                    sbomContentSection(sbom: sbom)
                } else {
                    emptySbomSection
                }

                // CVE History Section
                if !cveHistory.isEmpty {
                    cveHistorySection
                }
            }
            .padding()
        }
        .refreshable { await loadSbomData() }
        .task { await loadSbomData() }
        .sheet(isPresented: $showingRawJson) {
            NavigationStack {
                RawJsonView(content: rawJsonContent ?? "{}")
                    .navigationTitle("SBOM JSON")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingRawJson = false }
                        }
                    }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Software Bill of Materials")
                    .font(.headline)
            }

            HStack {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(SbomFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer()

                Button {
                    Task { await generateSbom() }
                } label: {
                    Label(
                        currentSbom != nil ? "Regenerate" : "Generate",
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)

                if currentSbom != nil {
                    Button {
                        Task { await showRawJson() }
                    } label: {
                        Label("JSON", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - SBOM Content Section

    @ViewBuilder
    private func sbomContentSection(sbom: SbomResponse) -> some View {
        // Stats Grid
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatBox(label: "Format", value: sbom.format.uppercased(), subvalue: "v\(sbom.formatVersion)")
            StatBox(label: "Components", value: "\(sbom.componentCount)")
            StatBox(label: "Dependencies", value: "\(sbom.dependencyCount)")
            StatBox(label: "Licenses", value: "\(sbom.licenseCount)")
        }

        // Licenses
        if !sbom.licenses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Detected Licenses")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(sbom.licenses, id: \.self) { license in
                        Text(license)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }

        // Components
        if !components.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Components (\(components.count))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(components.prefix(10)) { component in
                    ComponentRow(component: component)
                }

                if components.count > 10 {
                    Text("+\(components.count - 10) more components")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }

        // Generation info
        HStack {
            Text("Generated \(formattedDate(sbom.generatedAt))")
            if let generator = sbom.generator {
                Text("by \(generator)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Empty SBOM Section

    private var emptySbomSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No SBOM generated for this artifact yet.")
                .foregroundStyle(.secondary)

            Button {
                Task { await generateSbom() }
            } label: {
                Label("Generate \(selectedFormat.displayName) SBOM", systemImage: "doc.text")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - CVE History Section

    private var cveHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CVE History (\(cveHistory.count))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(cveHistory.prefix(5)) { cve in
                CveHistoryRow(cve: cve)
            }

            if cveHistory.count > 5 {
                Text("+\(cveHistory.count - 5) more CVEs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Actions

    private func loadSbomData() async {
        isLoading = sboms.isEmpty
        do {
            async let sbomsTask: [SbomResponse] = apiClient.request(
                "/api/v1/sbom?artifact_id=\(artifactId)"
            )
            async let cveTask: [CveHistoryEntry] = apiClient.request(
                "/api/v1/sbom/cve/history/\(artifactId)"
            )

            sboms = try await sbomsTask
            cveHistory = try await cveTask

            if let sbom = currentSbom {
                let comps: [SbomComponent] = try await apiClient.request(
                    "/api/v1/sbom/\(sbom.id)/components"
                )
                components = comps
            }
            errorMessage = nil
        } catch {
            if sboms.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func generateSbom() async {
        isGenerating = true
        do {
            let body = GenerateSbomRequest(
                artifactId: artifactId,
                format: selectedFormat.rawValue,
                forceRegenerate: currentSbom != nil
            )
            let _: SbomResponse = try await apiClient.request(
                "/api/v1/sbom",
                method: "POST",
                body: body
            )
            await loadSbomData()
        } catch {
            errorMessage = "Failed to generate SBOM: \(error.localizedDescription)"
        }
        isGenerating = false
    }

    private func showRawJson() async {
        guard let sbom = currentSbom else { return }
        do {
            let content: SbomContentResponse = try await apiClient.request("/api/v1/sbom/\(sbom.id)")
            let data = try JSONEncoder().encode(content.content)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                rawJsonContent = String(data: prettyData, encoding: .utf8)
            }
            showingRawJson = true
        } catch {
            // silent
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Helper Views

private struct StatBox: View {
    let label: String
    let value: String
    var subvalue: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            if let sub = subvalue {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ComponentRow: View {
    let component: SbomComponent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(component.name)
                .font(.subheadline.weight(.medium))

            if let version = component.version {
                Text(version)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }

            Spacer()

            if !component.licenses.isEmpty {
                Text(component.licenses.first ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CveHistoryRow: View {
    let cve: CveHistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cve.cveId)
                        .font(.subheadline.weight(.medium))

                    if let severity = cve.severity {
                        Text(severity.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(severityColor.opacity(0.1), in: Capsule())
                            .foregroundStyle(severityColor)
                    }

                    Text(cve.status.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }

                if let component = cve.affectedComponent {
                    Text("\(component)\(cve.affectedVersion.map { " @ \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formattedDate(cve.firstDetectedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusIcon: String {
        switch cve.status.lowercased() {
        case "fixed": return "checkmark.shield.fill"
        case "acknowledged": return "exclamationmark.triangle.fill"
        default: return "shield.fill"
        }
    }

    private var statusColor: Color {
        switch cve.status.lowercased() {
        case "fixed": return .green
        case "acknowledged": return .yellow
        default: return .red
        }
    }

    private var severityColor: Color {
        switch cve.severity?.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .blue
        default: return .purple
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

private struct RawJsonView: View {
    let content: String

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
    }
}

// MARK: - Flow Layout for tags

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, containerWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets

        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for size in sizes {
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (offsets, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

#Preview {
    NavigationStack {
        SbomView(artifactId: "test-id", artifactName: "test-artifact")
            .navigationTitle("SBOM")
    }
}

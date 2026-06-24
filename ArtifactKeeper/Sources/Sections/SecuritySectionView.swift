import SwiftUI

struct SecuritySectionView: View {
    @State private var selectedTab = "dashboard"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(["dashboard", "scans", "configs", "gates", "health", "policies", "licenses", "cves", "compliance"], id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                Text(tabTitle(for: tab))
                                    .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch selectedTab {
                    case "dashboard":
                        SecurityDashboardContentView()
                    case "scans":
                        SecurityScansContentView()
                    case "configs":
                        ScanConfigsView()
                    case "gates":
                        QualityGatesView()
                    case "health":
                        HealthDashboardView()
                    case "policies":
                        PoliciesView()
                    case "licenses":
                        LicensePoliciesView()
                    case "cves":
                        CveHistoryView()
                    case "compliance":
                        LicenseComplianceView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Security")
            .accountToolbar()
        }
    }

    private func tabTitle(for tab: String) -> String {
        switch tab {
        case "dashboard": return "Dashboard"
        case "scans": return "Scans"
        case "configs": return "Configs"
        case "gates": return "Gates"
        case "health": return "Health"
        case "policies": return "Policies"
        case "licenses": return "Licenses"
        case "cves": return "CVEs"
        case "compliance": return "Compliance"
        default: return tab.capitalized
        }
    }
}

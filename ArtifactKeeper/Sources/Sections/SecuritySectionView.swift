import SwiftUI

struct SecuritySectionView: View {
    @State private var selectedTab = "dashboard"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(["dashboard", "scans", "policies", "licenses"], id: \.self) { tab in
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
                    case "policies":
                        PoliciesView()
                    case "licenses":
                        LicensePoliciesView()
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
        case "policies": return "Policies"
        case "licenses": return "Licenses"
        default: return tab.capitalized
        }
    }
}

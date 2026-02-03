import SwiftUI

struct SecuritySectionView: View {
    @State private var selectedTab = "dashboard"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Dashboard").tag("dashboard")
                    Text("Scans").tag("scans")
                    Text("Policies").tag("policies")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
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
}

import SwiftUI

struct AdminSectionView: View {
    @State private var selectedTab = "users"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Users").tag("users")
                    Text("Groups").tag("groups")
                    Text("SSO").tag("sso")
                    Text("Settings").tag("settings")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch selectedTab {
                    case "users":
                        UsersView()
                    case "groups":
                        GroupsView()
                    case "sso":
                        SSOView()
                    case "settings":
                        SettingsContentView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Administration")
            .accountToolbar()
        }
    }
}

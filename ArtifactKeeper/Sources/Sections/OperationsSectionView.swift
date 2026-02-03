import SwiftUI

struct OperationsSectionView: View {
    @State private var selectedTab = "analytics"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Analytics").tag("analytics")
                    Text("Monitoring").tag("monitoring")
                    Text("Telemetry").tag("telemetry")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch selectedTab {
                    case "analytics":
                        AnalyticsView()
                    case "monitoring":
                        MonitoringView()
                    case "telemetry":
                        TelemetryView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Operations")
            .accountToolbar()
        }
    }
}

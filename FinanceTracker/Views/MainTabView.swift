import SwiftUI

struct RecapSheetItem: Identifiable {
    let id = UUID()
    let month: String
    var recapType: String = "monthly"
}

struct MainTabView: View {
    @State private var recapItem: RecapSheetItem?
    @State private var checkedRecapThisSession = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Dashboard")
                }

            TransactionsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Transactions")
                }

            BudgetsView()
                .tabItem {
                    Image(systemName: "chart.pie")
                    Text("Budgets")
                }

            GoalsView()
                .tabItem {
                    Image(systemName: "target")
                    Text("Goals")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .tint(Theme.Colors.teal)
        .onAppear {
            if !checkedRecapThisSession {
                checkedRecapThisSession = true
                checkForUnviewedRecap()
            }
        }
        .sheet(item: $recapItem) { item in
            MonthlyRecapView(month: item.month, recapType: item.recapType, onDismiss: { recapItem = nil })
        }
    }

    private func checkForUnviewedRecap() {
        Task {
            do {
                // Check for unviewed monthly recap first
                let monthlyCheck: RecapCheckResponse = try await APIClient.shared.request(
                    "/api/recap?check_unviewed=true&type=monthly"
                )
                if monthlyCheck.hasUnviewed, let month = monthlyCheck.month {
                    recapItem = RecapSheetItem(month: month, recapType: "monthly")
                    return
                }

                // Then check for unviewed mid-month recap
                let midCheck: RecapCheckResponse = try await APIClient.shared.request(
                    "/api/recap?check_unviewed=true&type=mid_month"
                )
                if midCheck.hasUnviewed, let month = midCheck.month {
                    recapItem = RecapSheetItem(month: month, recapType: "mid_month")
                }
            } catch {
                print("Recap check error:", error)
            }
        }
    }
}

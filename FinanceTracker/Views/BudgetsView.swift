import SwiftUI

struct BudgetsView: View {
    @State private var month = DashboardView.currentMonth()
    @State private var categories: [Category] = []
    @State private var budgets: [Budget] = []
    @State private var transactions: [Transaction] = []
    @State private var loading = true

    var expenseCategories: [Category] {
        categories.filter { $0.category_type == "expense" && $0.parent_id == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button(action: { adjustMonth(-1) }) {
                            Image(systemName: "chevron.left")
                        }
                        Text(Formatters.monthLabel(month))
                            .font(.system(size: 14, weight: .medium))
                        Button(action: { adjustMonth(1) }) {
                            Image(systemName: "chevron.right")
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    if loading {
                        ProgressView().padding(.top, 40)
                    } else {
                        ForEach(expenseCategories) { cat in
                            let budget = budgets.first(where: { $0.category_id == cat.id })?.amount ?? 0
                            let actual = getActual(for: cat.id)
                            let remaining = budget - actual
                            let pct = budget > 0 ? min(1.0, actual / budget) : 0
                            let over = remaining < 0

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(cat.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Theme.Colors.text)
                                    Spacer()
                                    if budget > 0 {
                                        Text(Formatters.currency(remaining, decimals: false))
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(over ? Theme.Colors.error : Theme.Colors.success)
                                    }
                                }

                                if budget > 0 {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Theme.Colors.border)
                                                .frame(height: 4)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(over ? Theme.Colors.error : pct > 0.8 ? Theme.Colors.warning : Theme.Colors.accent)
                                                .frame(width: geo.size.width * pct, height: 4)
                                        }
                                    }
                                    .frame(height: 4)

                                    HStack {
                                        Text("\(Formatters.currency(actual, decimals: false)) of \(Formatters.currency(budget, decimals: false))")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.Colors.textMuted)
                                        Spacer()
                                    }
                                } else {
                                    Text("No budget set")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.Colors.textDisabled)
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.Colors.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { loadData() }
    }

    func adjustMonth(_ delta: Int) {
        let parts = month.split(separator: "-")
        guard parts.count == 2, var m = Int(parts[1]), var y = Int(parts[0]) else { return }
        m += delta
        if m > 12 { m = 1; y += 1 }
        if m < 1 { m = 12; y -= 1 }
        month = "\(y)-\(String(format: "%02d", m))"
        loadData()
    }

    func getActual(for categoryId: Int) -> Double {
        let childIds = categories.filter { $0.parent_id == categoryId }.map { $0.id }
        let allIds = [categoryId] + childIds
        return transactions
            .filter { allIds.contains($0.category_id ?? -1) }
            .reduce(0) { $0 + abs($1.amount) }
    }

    func loadData() {
        loading = true
        Task {
            do {
                categories = try await APIClient.shared.request("/api/categories")
                budgets = try await APIClient.shared.request("/api/budgets?month=\(month)")
                transactions = try await APIClient.shared.request("/api/transactions?month=\(month)")
            } catch {
                print("Load error:", error)
            }
            loading = false
        }
    }
}

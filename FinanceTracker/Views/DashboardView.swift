import SwiftUI

enum DashboardSheet: Identifiable {
    case income
    case savings

    var id: String {
        switch self {
        case .income: return "income"
        case .savings: return "savings"
        }
    }
}

struct DashboardView: View {
    @State private var month = Self.currentMonth()
    @State private var isYTD = false
    @State private var dashboardData: DashboardData?
    @State private var loading = true
    @State private var activeSheet: DashboardSheet?
    @State private var healthcareNavActive = false
    @State private var returnsNavActive = false
    @State private var refundNavActive = false
    @State private var flexibleNavActive = false
    @State private var fixedNavActive = false
    @State private var creditTriageNavActive = false
    @State private var spreadNavActive = false
    @State private var showAmortizeSuggest = false
    @State private var dismissedAmortizeSuggestion = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Month picker
                    HStack {
                        Button(action: { adjustMonth(-1) }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        Text(isYTD ? "\(month.prefix(4)) YTD" : Formatters.monthLabel(month))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.text)

                        Button(action: { adjustMonth(1) }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        Spacer()

                        Button(isYTD ? "Month" : "YTD") {
                            isYTD.toggle()
                            loadData()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)

                    if loading && dashboardData == nil {
                        ProgressView()
                            .padding(.top, 60)
                    } else if let data = dashboardData {
                        let savings = data.savingsTarget ?? 0

                        // 1. Pulse - Flexible Remaining (with inline amortize suggestion)
                        PulseCardView(
                            flexibleRemaining: data.summary.flexibleRemaining,
                            flexibleBudget: data.summary.flexibleBudget,
                            daysRemaining: data.summary.daysRemaining,
                            dailyBudget: data.summary.dailyBudget,
                            savingsTarget: savings,
                            onGoalTap: { activeSheet = .savings },
                            amortizeSuggestion: (!dismissedAmortizeSuggestion && data.amortization?.largeUnamortizedExpense != nil)
                                ? AmortizeSuggestion(
                                    amount: data.amortization!.largeUnamortizedExpense!.amount,
                                    description: data.amortization!.largeUnamortizedExpense!.description
                                ) : nil,
                            onAmortizeTap: { showAmortizeSuggest = true },
                            onAmortizeDismiss: { dismissedAmortizeSuggestion = true }
                        )
                        .padding(.horizontal)

                        // 2. Cash Flow (nodes tappable + badge pills)
                        FlowCardView(
                            netIncome: data.summary.netIncome,
                            fixedTotal: max(data.summary.fixedExpenses, data.summary.expectedFixed ?? 0),
                            flexibleTotal: data.summary.flexibleExpenses,
                            savingsTarget: savings,
                            spreadTotal: data.summary.spreadExpenses ?? 0,
                            healthcareTotal: data.healthcare.totalReimbursed,
                            healthcarePaidTotal: data.healthcare.totalPaid,
                            healthcareAwaitingTotal: data.healthcare.pendingReimbursement,
                            creditBadgeCount: data.windfall?.unallocatedCount ?? 0,
                            creditBadgeTotal: data.windfall?.unallocatedTotal ?? 0,
                            pendingReturns: data.netCash?.pendingReturns ?? 0,
                            expectedFixed: data.summary.expectedFixed,
                            actualFixed: data.summary.fixedExpenses,
                            onNodeTap: { nodeId in
                                switch nodeId {
                                case "income": activeSheet = .income
                                case "fixed": fixedNavActive = true
                                case "flexible": flexibleNavActive = true
                                case "savings": activeSheet = .savings
                                case "spread": spreadNavActive = true
                                case "healthcare": healthcareNavActive = true
                                default: break
                                }
                            },
                            onCreditBadgeTap: { creditTriageNavActive = true },
                            onRefundTap: { refundNavActive = true }
                        )
                        .padding(.horizontal)

                        // 3. Net Cash (simplified — no callouts)
                        if let netCash = data.netCash {
                            NetCashCardView(metrics: netCash)
                                .padding(.horizontal)
                        }

                        // 4. Pending Healthcare & Returns callouts
                        if data.healthcare.pendingReimbursement > 0 || (data.returns?.pendingAmount ?? 0) > 0 {
                            HStack(spacing: 10) {
                                if data.healthcare.pendingReimbursement > 0 {
                                    Button {
                                        healthcareNavActive = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(Color(hex: "#b45309"))
                                            Text("Healthcare")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#b45309"))
                                            Spacer()
                                            Text(Formatters.currency(data.healthcare.pendingReimbursement, decimals: false))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(hex: "#b45309"))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "#fef3e2"))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: "#fde68a"), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                if (data.returns?.pendingAmount ?? 0) > 0 {
                                    Button {
                                        returnsNavActive = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.left")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(Color(hex: "#7c3aed"))
                                            Text("Returns")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#7c3aed"))
                                            Spacer()
                                            Text(Formatters.currency(data.returns!.pendingAmount, decimals: false))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(hex: "#7c3aed"))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "#f3e8ff"))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: "#e9d5ff"), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Text("No data for this period")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textMuted)
                            .padding(.top, 60)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .refreshable {
                // Sync from Plaid first, then reload dashboard
                let _: SyncResult? = try? await APIClient.shared.request(
                    "/api/plaid/sync",
                    method: "POST"
                )
                let params = isYTD
                    ? "year=\(month.prefix(4))&include_balances=true"
                    : "month=\(month)&include_balances=true"
                dashboardData = try? await APIClient.shared.request("/api/dashboard?\(params)")
            }
            .background(Theme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet) { sheet in
                if let data = dashboardData {
                    switch sheet {
                    case .income:
                        IncomeBreakdownSheet(
                            grossIncome: data.summary.grossIncome,
                            netIncome: data.summary.netIncome,
                            incomeBreakdown: data.incomeBreakdown
                        )
                    case .savings:
                        SavingsGoalSheet(month: month, onSave: { loadData() })
                    }
                }
            }
            .navigationDestination(isPresented: $fixedNavActive) {
                if let data = dashboardData {
                    SpendingDetailView(
                        title: "Fixed Expenses",
                        barLabel: "Fixed",
                        items: data.breakdown.fixed,
                        groupedItems: data.breakdown.fixed,
                        budget: data.summary.fixedExpenses,
                        barColor: "#666",
                        month: month,
                        fixedFilter: true
                    )
                }
            }
            .navigationDestination(isPresented: $flexibleNavActive) {
                if let data = dashboardData {
                    SpendingDetailView(
                        title: "Flexible Spending",
                        barLabel: "Flexible",
                        items: data.breakdown.flexible,
                        groupedItems: data.breakdown.flexibleGrouped ?? data.breakdown.flexible,
                        budget: data.summary.flexibleBudget,
                        barColor: "#0d9488",
                        month: month,
                        fixedFilter: false
                    )
                }
            }
            .navigationDestination(isPresented: $healthcareNavActive) {
                HealthcareDetailView(month: month)
            }
            .navigationDestination(isPresented: $returnsNavActive) {
                ReturnsDetailView(month: month)
            }
            .navigationDestination(isPresented: $spreadNavActive) {
                if let items = dashboardData?.amortization?.spreadBreakdown {
                    SpreadDetailView(items: items, month: month, onUpdate: { loadData() })
                }
            }
            .navigationDestination(isPresented: $creditTriageNavActive) {
                CreditTriageView(month: month, onAllocated: { loadData() })
            }
            .navigationDestination(isPresented: $refundNavActive) {
                RefundsView(month: month)
            }
            .onChange(of: fixedNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: flexibleNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: healthcareNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: returnsNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: spreadNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: creditTriageNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: refundNavActive) { old, new in if old && !new { loadData() } }
            .onChange(of: activeSheet) { old, new in if old != nil && new == nil { loadData() } }
            .sheet(isPresented: $showAmortizeSuggest) {
                if let suggestion = dashboardData?.amortization?.largeUnamortizedExpense {
                    AmortizeSheet(
                        transactionId: suggestion.id,
                        transactionAmount: -suggestion.amount,
                        transactionDescription: suggestion.description,
                        transactionDate: suggestion.date,
                        onAmortized: {
                            dismissedAmortizeSuggestion = true
                            loadData()
                        }
                    )
                }
            }
        }
        .onAppear { syncThenLoad() }
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

    func loadData() {
        loading = true
        Task {
            do {
                let params = isYTD
                    ? "year=\(month.prefix(4))&include_balances=true"
                    : "month=\(month)&include_balances=true"

                dashboardData = try await APIClient.shared.request("/api/dashboard?\(params)")
            } catch {
                print("Dashboard load error:", error)
            }
            loading = false
        }
    }

    func syncThenLoad() {
        // Load dashboard immediately with existing data
        loadData()
        // Sync transactions from Plaid in the background, then reload
        Task {
            do {
                let _: SyncResult = try await APIClient.shared.request(
                    "/api/plaid/sync",
                    method: "POST"
                )
                // Reload dashboard to pick up any new transactions
                loadData()
            } catch {
                print("Auto-sync error:", error)
            }
        }
    }

    static func currentMonth() -> String {
        let d = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        return "\(y)-\(String(format: "%02d", m))"
    }
}

// MARK: - Category Breakdown Sheet

struct CategoryBreakdownSheet: View {
    let title: String
    let items: [CategoryTotal]
    let total: Double
    var month: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CategoryTotal?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary
                    HStack {
                        Text("Total")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.currency(total, decimals: false))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Colors.text)
                    }
                    .cardStyle()

                    // Treemap-style breakdown
                    if !items.isEmpty {
                        GeometryReader { geo in
                            TreemapLayout(
                                categories: items,
                                total: total,
                                width: geo.size.width,
                                onCategoryTap: { cat in selectedCategory = cat }
                            )
                        }
                        .frame(height: TreemapLayout.height(for: min(items.count, 8)))
                    } else {
                        Text("No expenses in this category")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .background(Theme.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .sheet(item: $selectedCategory) { cat in
                CategoryTransactionsSheet(
                    categoryName: cat.name,
                    categoryId: cat.id,
                    month: month
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}

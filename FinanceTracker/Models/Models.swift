import Foundation

struct Transaction: Codable, Identifiable {
    let id: Int
    let date: String
    let amount: Double
    let description: String?
    let category_id: Int?
    let category_name: String?
    let category_type: String?
    let parent_category_name: String?
    let category_color: String?
    let account_name: String?
    let account_type: String?
    let created_by_name: String?
    let is_one_time: Bool?
    let is_healthcare: Bool?
    let reimbursement_status: String?
    let is_return: Bool?
    let return_status: String?
    let is_fixed: Bool?
    let credit_allocation: String?
    let allocated_goal_id: Int?
    let is_amortized: Bool?
    let amortize_months: Int?
    let amortize_start: String?
    let amortize_goal_id: Int?
}

struct Category: Codable, Identifiable {
    let id: Int
    let name: String
    let category_type: String?
    let parent_id: Int?
    let color: String?
    let sort_order: Int?
}

struct Account: Codable, Identifiable {
    let id: Int
    let name: String
    let account_type: String
    let is_active: Bool?
}

struct Budget: Codable, Identifiable {
    let id: Int
    let category_id: Int
    let month: String
    let amount: Double
}

struct SankeyData: Codable {
    let nodes: [SankeyNode]
    let links: [SankeyLink]
}

struct SankeyNode: Codable, Identifiable {
    let id: String
    let label: String
    let color: String
}

struct SankeyLink: Codable {
    let source: String
    let target: String
    let value: Double
}

struct PlaidItem: Codable, Identifiable {
    let id: Int
    let item_id: String
    let institution_name: String
    let status: String
    let last_synced: String?
}

struct SyncResult: Codable {
    let synced: Int
    let transactions_added: Int
    let transactions_removed: Int
    let returns_matched: Int?
}

struct InsertResult: Codable {
    let id: Int
}

struct OkResult: Codable {
    let ok: Bool
}

// MARK: - Dashboard Data

struct DashboardData: Codable {
    let summary: DashboardSummary
    let healthcare: HealthcareMetrics
    let returns: ReturnsMetrics?
    let netCash: NetCashMetrics?
    let treemap: [CategoryTotal]?
    let breakdown: CategoryBreakdown
    let recentTransactions: [RecentTransaction]
    let incomeBreakdown: IncomeBreakdown?
    let expectedFixed: Double?
    let expectedFixedBreakdown: [CategoryTotal]?
    let savingsTarget: Double?
    let windfall: WindfallMetrics?
    let amortization: AmortizationMetrics?
}

struct AmortizationMetrics: Codable {
    let amortizedExpenses: Double
    let spreadBreakdown: [SpreadItem]?
    let largeUnamortizedExpense: LargeExpenseSuggestion?
}

struct SpreadItem: Codable, Identifiable {
    let id: Int
    let description: String
    let totalAmount: Double
    let monthlyPortion: Double
    let months: Int
    let startMonth: String
    let categoryName: String
}

struct LargeExpenseSuggestion: Codable {
    let id: Int
    let description: String
    let amount: Double
    let date: String
}

struct WindfallMetrics: Codable {
    let unallocatedCount: Int
    let unallocatedTotal: Double
}

struct DashboardSummary: Codable {
    let grossIncome: Double
    let netIncome: Double
    let fixedExpenses: Double
    let expectedFixed: Double?
    let flexibleExpenses: Double
    let spreadExpenses: Double?
    let totalExpenses: Double
    let savings: Double
    let flexibleBudget: Double
    let flexibleRemaining: Double
    let daysRemaining: Int
    let dailyBudget: Double
}

struct HealthcareMetrics: Codable {
    let totalPaid: Double
    let pendingReimbursement: Double
    let totalReimbursed: Double
    let netCost: Double
}

struct ReturnsMetrics: Codable {
    let pendingAmount: Double
    let receivedAmount: Double
    let totalReturns: Double
}

struct NetCashMetrics: Codable {
    let checking: Double
    let creditDebt: Double
    let pendingHealthcare: Double
    let pendingReturns: Double
    let net: Double
    let goalEarmarked: Double?
}

struct IncomeBreakdown: Codable {
    let income: [CategoryTotal]
    let deductions: [CategoryTotal]
}

struct CategoryBreakdown: Codable {
    let fixed: [CategoryTotal]
    let flexible: [CategoryTotal]
    let flexibleGrouped: [CategoryTotal]?
}

struct CategoryTotal: Codable, Identifiable {
    let id: Int
    let name: String
    let amount: Double
    let color: String
}

struct RecentTransaction: Codable, Identifiable {
    let id: Int
    let date: String
    let description: String
    let amount: Double
    let categoryName: String
    let categoryColor: String
    let isOneTime: Bool
    let isHealthcare: Bool
}

// MARK: - Detail Items

struct HealthcareItem: Codable, Identifiable {
    let id: Int
    let date: String
    let amount: Double
    let description: String?
    let reimbursement_status: String?
    let reimbursed_amount: Double?
}

struct ReturnItem: Codable, Identifiable {
    let id: Int
    let date: String
    let amount: Double
    let description: String?
    let return_status: String?
}

// MARK: - Goals

struct Goal: Codable, Identifiable {
    let id: Int
    let name: String
    let goalType: String
    let targetAmount: Double
    let currentAmount: Double
    let deadline: String?
    let categoryId: Int?
    let isSavingsTarget: Bool?
    let isPayoff: Bool?
}

struct GoalsResponse: Codable {
    let goals: [Goal]
}

struct GoalResponse: Codable {
    let goal: GoalData
}

struct GoalData: Codable {
    let id: Int
    let name: String
    let goal_type: String
    let target_amount: Double
    let current_amount: Double
    let deadline: String?
    let category_id: Int?
}

// MARK: - Monthly Recap

struct RecapCheckResponse: Codable {
    let hasUnviewed: Bool
    let month: String?
    let recap_type: String?
}

struct RecapResponse: Codable {
    let recap: RecapData?
    let allocations: [RecapAllocation]?
    let options: AllocationOptions?
}

struct RecapAllocation: Codable, Identifiable {
    let id: Int
    let recap_id: Int
    let allocation_type: String
    let amount: Double
    let target_goal_id: Int?
    let target_transaction_id: Int?
    let created_transaction_id: Int?
}

struct AllocationOptions: Codable {
    let goals: [AllocationGoalOption]?
    let spreads: [AllocationSpreadOption]?
}

struct AllocationGoalOption: Codable, Identifiable {
    let id: Int
    let name: String
    let targetAmount: Double
    let currentAmount: Double
    let remaining: Double
}

struct AllocationSpreadOption: Codable, Identifiable {
    let id: Int
    let description: String
    let totalAmount: Double
    let monthlyPortion: Double
    let monthsRemaining: Int
}

struct AllocateResponse: Codable {
    let allocation: RecapAllocation?
    let complete: Bool?
}

struct RecapData: Codable {
    let id: Int
    let month: String
    let recap_type: String?
    let gross_income: Double
    let net_income: Double
    let fixed_expenses: Double
    let flexible_expenses: Double
    let spread_expenses: Double
    let total_expenses: Double
    let savings_target: Double
    let flexible_budget: Double
    let surplus_deficit: Double
    let net_cash_checking: Double?
    let net_cash_credit_debt: Double?
    let net_cash_total: Double?
    let healthcare_paid: Double
    let healthcare_pending: Double
    let healthcare_reimbursed: Double
    let returns_pending: Double
    let returns_received: Double
    let top_categories: [RecapCategory]?
    let top_transactions: [RecapTransaction]?
    let goals_snapshot: [RecapGoal]?
    let spread_snapshot: [RecapSpread]?
    let income_breakdown: [RecapIncomeItem]?
    let advisor_headline: String
    let advisor_body: String
    let advisor_tone: String
    let allocation_status: String
    let is_viewed_by_user: Bool?
    let mid_month_metrics: MidMonthMetrics?
    let regenerated_at: String?
}

struct MidMonthMetrics: Codable {
    let daysElapsed: Int
    let totalDays: Int
    let dailyAverageSpend: Double
    let projectedMonthTotal: Double
    let dailyBudgetNeeded: Double
    let onTrack: Bool
    let spendingPacePercent: Int
}

struct RecapCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    let color: String
    let isFixed: Bool?
}

struct RecapTransaction: Codable, Identifiable {
    var id: String { "\(description)-\(date)" }
    let description: String
    let amount: Double
    let date: String
    let categoryName: String
}

struct RecapGoal: Codable, Identifiable {
    let id: Int
    let name: String
    let goalType: String
    let targetAmount: Double
    let currentAmount: Double
    let progress: Double
}

struct RecapSpread: Codable, Identifiable {
    let id: Int
    let description: String
    let totalAmount: Double
    let monthlyPortion: Double
    let monthsRemaining: Int
}

struct RecapIncomeItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
}

// MARK: - Credit Triage

struct CreditItem: Codable, Identifiable {
    let id: Int
    let date: String
    let amount: Double
    let description: String?
    let categoryName: String?
    let accountName: String?
    let allocatedAmount: Double?
    let remainingAmount: Double?
    let allocations: [CreditSubAllocation]?
}

struct CreditSubAllocation: Codable, Identifiable {
    let id: Int
    let type: String
    let amount: Double
    let label: String?
}

struct SearchTransaction: Codable, Identifiable {
    let id: Int
    let date: String
    let amount: Double
    let description: String?
    let categoryName: String?
    let accountName: String?
    let isReturn: Bool?
    let returnStatus: String?
    let returnedAmount: Double?
    let isHealthcare: Bool?
    let reimbursementStatus: String?
    let reimbursedAmount: Double?
    let remainingAmount: Double?
}

struct TransactionSearchResponse: Codable {
    let tagged: [SearchTransaction]
    let suggested: SearchTransaction?
    let results: [SearchTransaction]
}

struct GoalOption: Codable, Identifiable {
    let id: Int
    let name: String
    let targetAmount: Double
    let currentAmount: Double
    let remaining: Double
}

struct UnallocatedCreditsResponse: Codable {
    let credits: [CreditItem]
    let allocatedCredits: [CreditItem]?
    let goals: [GoalOption]
    let expenseCategories: [Category]
    let pendingReturns: [ReturnItem]
    let spreadItems: [SpreadItem]?
}

struct CreditDetailItem: Codable, Identifiable {
    let id: Int
    let date: String
    let amount: Double
    let description: String?
    let creditAllocation: String?
    let categoryName: String?
    let goalName: String?
}

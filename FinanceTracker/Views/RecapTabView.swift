import SwiftUI

struct RecapTabView: View {
    @State private var month: String = {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return String(format: "%04d-%02d", y, m)
    }()
    @State private var recapType: String = "mid_month"
    @State private var recap: RecapData?
    @State private var allocations: [RecapAllocation] = []
    @State private var goalOptions: [AllocationGoalOption] = []
    @State private var spreadOptions: [AllocationSpreadOption] = []
    @State private var loading = true
    @State private var regenerating = false
    @State private var generating = false
    @State private var toastError: String? = nil
    @State private var toastSuccess: String? = nil

    private var isMidMonth: Bool { (recap?.recap_type ?? recapType) == "mid_month" }
    private var isSurplus: Bool { (recap?.surplus_deficit ?? 0) > 0 }
    private var isDeficit: Bool { (recap?.surplus_deficit ?? 0) < 0 }
    private var surplusColor: Color {
        isSurplus ? Theme.Colors.success : isDeficit ? Theme.Colors.error : Theme.Colors.textSecondary
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigator
                monthNavigator

                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let recap = recap {
                    ScrollView {
                        VStack(spacing: 24) {
                            heroSection(recap)

                            if isMidMonth, let mm = recap.mid_month_metrics {
                                midMonthPaceSection(recap, metrics: mm)

                                if let hist = mm.historical {
                                    historicalComparisonSection(hist, dayOfMonth: mm.daysElapsed)
                                }
                            }

                            // Allocation summary for monthly recaps (read-only in tab)
                            if !isMidMonth && abs(recap.surplus_deficit) >= 1 {
                                allocationSummarySection(recap)
                            }

                            numbersSection(recap)
                            topExpensesSection(recap)

                            if recap.net_cash_total != nil {
                                netCashSection(recap)
                            }
                            if recap.healthcare_paid > 0 || recap.returns_pending > 0 || recap.returns_received > 0 {
                                healthcareReturnsSection(recap)
                            }
                            if let goals = recap.goals_snapshot, !goals.isEmpty {
                                goalsSection(goals)
                            }
                            if let spreads = recap.spread_snapshot, !spreads.isEmpty {
                                spreadsSection(spreads)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.Colors.textDisabled)
                        Text("No recap for this month")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Button {
                            generateRecap()
                        } label: {
                            HStack(spacing: 6) {
                                if generating {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                }
                                Text("Generate Now")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Theme.Colors.accent)
                            .cornerRadius(8)
                        }
                        .disabled(generating)
                    }
                    Spacer()
                }
            }
            .background(Theme.Colors.background)
            .toastError($toastError)
            .toastSuccess($toastSuccess)
            .navigationTitle("Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        regenerateRecap()
                    } label: {
                        if regenerating {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }
                    }
                    .disabled(regenerating || recap == nil)
                }
            }
        }
        .onAppear { loadRecap() }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    month = Formatters.addMonths(month, -1)
                    recapType = "monthly" // past months default to monthly
                    loading = true
                    recap = nil
                    loadRecap()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                Text(monthDisplayLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.text)

                Spacer()

                Button {
                    month = Formatters.addMonths(month, 1)
                    let now = Date()
                    let cal = Calendar.current
                    let curMonth = String(format: "%04d-%02d", cal.component(.year, from: now), cal.component(.month, from: now))
                    recapType = month == curMonth ? "mid_month" : "monthly"
                    loading = true
                    recap = nil
                    loadRecap()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)

            // Type toggle
            HStack(spacing: 0) {
                typeToggleButton("Monthly", type: "monthly")
                typeToggleButton("Check-In", type: "mid_month")
            }
            .background(Theme.Colors.subtleBg)
            .cornerRadius(6)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Theme.Colors.surface)
    }

    private func typeToggleButton(_ label: String, type: String) -> some View {
        Button {
            if recapType != type {
                recapType = type
                loading = true
                recap = nil
                loadRecap()
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(recapType == type ? .white : Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(recapType == type ? Theme.Colors.accent : Color.clear)
                )
        }
    }

    private var monthDisplayLabel: String {
        Formatters.monthLabel(month)
    }

    // MARK: - Hero

    private func heroSection(_ r: RecapData) -> some View {
        VStack(spacing: 12) {
            if isMidMonth {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.accent)
                    Text("MID-MONTH CHECK-IN")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)
                        .tracking(1.5)
                }
            } else {
                Text(monthDisplayLabel.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .tracking(1.5)
            }

            Text(r.advisor_headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.Colors.text)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            Text(r.advisor_body)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Mid-Month Pace

    private func midMonthPaceSection(_ r: RecapData, metrics mm: MidMonthMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPENDING PACE")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            let paceColor: Color = mm.onTrack ? Theme.Colors.success :
                mm.spendingPacePercent <= 120 ? Theme.Colors.warning : Theme.Colors.error

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(mm.spendingPacePercent)%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(paceColor)
                        Text("of pace")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Text("Day \(mm.daysElapsed) of \(mm.totalDays)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
                RingGaugeView(
                    value: Double(mm.daysElapsed),
                    maxValue: Double(mm.totalDays),
                    size: 56,
                    strokeWidth: 6,
                    color: paceColor
                ) {
                    Text("\(mm.totalDays - mm.daysElapsed)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(paceColor)
                }
            }

            Divider()

            HStack(spacing: 0) {
                metricColumn(label: "Avg/Day", value: Formatters.currency(mm.dailyAverageSpend, decimals: false), color: Theme.Colors.text)
                metricColumn(label: "Need/Day", value: Formatters.currency(max(mm.dailyBudgetNeeded, 0), decimals: false), color: paceColor)
                metricColumn(label: "Projected", value: Formatters.currency(mm.projectedMonthTotal, decimals: false),
                             color: mm.projectedMonthTotal <= r.flexible_budget ? Theme.Colors.success : Theme.Colors.error)
            }
        }
        .cardStyle()
    }

    // MARK: - Historical Comparison

    private func historicalComparisonSection(_ hist: HistoricalComparison, dayOfMonth: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VS PREVIOUS MONTHS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            // vs Last Month
            HStack {
                Text("By day \(dayOfMonth) last month")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                Text(Formatters.currency(hist.priorMonthSamePoint, decimals: false))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
            }

            HStack {
                Text("Change vs last month")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                let vsLast = hist.vsLastMonth
                HStack(spacing: 3) {
                    Image(systemName: vsLast > 0 ? "arrow.up.right" : vsLast < 0 ? "arrow.down.right" : "minus")
                        .font(.system(size: 10))
                    Text(String(format: "%.1f%%", abs(vsLast)))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(vsLast > 5 ? Theme.Colors.error : vsLast < -5 ? Theme.Colors.success : Theme.Colors.textSecondary)
            }

            HStack {
                Text("vs 3-month average")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                let vsAvg = hist.vsAverage
                HStack(spacing: 3) {
                    Image(systemName: vsAvg > 0 ? "arrow.up.right" : vsAvg < 0 ? "arrow.down.right" : "minus")
                        .font(.system(size: 10))
                    Text(String(format: "%.1f%%", abs(vsAvg)))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(vsAvg > 5 ? Theme.Colors.error : vsAvg < -5 ? Theme.Colors.success : Theme.Colors.textSecondary)
            }

            // Top category deltas
            if let deltas = hist.topCategoryDeltas, !deltas.isEmpty {
                Divider()
                Text("BIGGEST CHANGES")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .tracking(0.5)

                ForEach(deltas) { d in
                    HStack {
                        Text(d.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.text)
                            .lineLimit(1)
                        Spacer()
                        let isUp = d.delta > 0
                        Text("\(isUp ? "+" : "")\(Formatters.currency(d.delta, decimals: false))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isUp ? Theme.Colors.error : Theme.Colors.success)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Allocation Summary (read-only)

    private func allocationSummarySection(_ r: RecapData) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: isSurplus ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(surplusColor)
                    .font(.system(size: 16))
                Text("\(Formatters.currency(abs(r.surplus_deficit), decimals: false)) \(isSurplus ? "surplus" : "over budget")")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(surplusColor)
            }

            if !allocations.isEmpty {
                VStack(spacing: 6) {
                    ForEach(allocations) { alloc in
                        HStack(spacing: 8) {
                            Image(systemName: allocationIcon(alloc.allocation_type))
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textMuted)
                                .frame(width: 16)
                            Text(Formatters.currency(alloc.amount, decimals: false))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Colors.text)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(Theme.Colors.textDisabled)
                            Text(allocationTargetLabel(alloc))
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.subtleBg))
                    }
                }
            } else if r.allocation_status == "pending" {
                Text("Not yet allocated")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
        .padding(16)
        .background(Theme.Colors.surface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.border, lineWidth: 1))
    }

    // MARK: - Numbers

    private func numbersSection(_ r: RecapData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE IT WENT")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            barRow(label: "Net Income", amount: r.net_income, maxAmount: r.net_income, color: Theme.Colors.success)
            barRow(label: "Fixed", amount: r.fixed_expenses, maxAmount: r.net_income, color: Theme.Colors.textSecondary)
            barRow(label: "Flexible", amount: r.flexible_expenses, maxAmount: r.net_income, color: Theme.Colors.accent)

            if r.spread_expenses > 0 {
                barRow(label: "Payoff", amount: r.spread_expenses, maxAmount: r.net_income, color: Theme.Colors.rose)
            }
            if r.savings_target > 0 {
                barRow(label: "Saving", amount: r.savings_target, maxAmount: r.net_income, color: Theme.Colors.teal)
            }

            if !isMidMonth {
                Divider()
                HStack {
                    Text(isSurplus ? "Surplus" : isDeficit ? "Deficit" : "Even")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.text)
                    Spacer()
                    Text(Formatters.currency(abs(r.surplus_deficit), decimals: false))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(surplusColor)
                }
            }
        }
        .cardStyle()
    }

    private func barRow(label: String, amount: Double, maxAmount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.text)
                Spacer()
                Text(Formatters.currency(amount, decimals: false)).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.subtleBg).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: maxAmount > 0 ? geo.size.width * CGFloat(min(amount / maxAmount, 1)) : 0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Top Expenses

    private func topExpensesSection(_ r: RecapData) -> some View {
        let categories = (r.top_categories ?? []).filter { $0.isFixed != true }.prefix(5)
        guard !categories.isEmpty else { return AnyView(EmptyView()) }
        let maxAmount = categories.map(\.amount).max() ?? 1

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("TOP SPENDING")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .tracking(1)

                ForEach(Array(categories)) { cat in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: cat.color)).frame(width: 8, height: 8)
                        Text(cat.name).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.text).lineLimit(1)
                        Spacer()
                        Text(Formatters.currency(cat.amount, decimals: false)).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.subtleBg).frame(height: 5)
                            RoundedRectangle(cornerRadius: 3).fill(Color(hex: cat.color).opacity(0.6))
                                .frame(width: maxAmount > 0 ? geo.size.width * CGFloat(cat.amount / maxAmount) : 0, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .cardStyle()
        )
    }

    // MARK: - Net Cash

    private func netCashSection(_ r: RecapData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NET CASH").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.Colors.textMuted).tracking(1)
            if let checking = r.net_cash_checking {
                HStack { Text("Checking").font(.system(size: 13)).foregroundColor(Theme.Colors.textSecondary); Spacer()
                    Text(Formatters.currency(checking, decimals: false)).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.Colors.text) }
            }
            if let credit = r.net_cash_credit_debt {
                HStack { Text("Credit Debt").font(.system(size: 13)).foregroundColor(Theme.Colors.textSecondary); Spacer()
                    Text(Formatters.currency(credit, decimals: false)).font(.system(size: 13, weight: .medium)).foregroundColor(credit < 0 ? Theme.Colors.error : Theme.Colors.text) }
            }
            Divider()
            if let total = r.net_cash_total {
                HStack { Text("Net Total").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.Colors.text); Spacer()
                    Text(Formatters.currency(total, decimals: false)).font(.system(size: 14, weight: .bold)).foregroundColor(total >= 0 ? Theme.Colors.success : Theme.Colors.error) }
            }
        }
        .cardStyle()
    }

    // MARK: - Healthcare & Returns

    private func healthcareReturnsSection(_ r: RecapData) -> some View {
        HStack(spacing: 12) {
            if r.healthcare_paid > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEALTHCARE").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.Colors.textMuted).tracking(1)
                    statLine("Paid", Formatters.currency(r.healthcare_paid, decimals: false))
                    statLine("Awaiting", Formatters.currency(r.healthcare_pending, decimals: false))
                    statLine("Reimbursed", Formatters.currency(r.healthcare_reimbursed, decimals: false))
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.border, lineWidth: 1))
            }
            if r.returns_pending > 0 || r.returns_received > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RETURNS").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.Colors.textMuted).tracking(1)
                    statLine("Awaiting", Formatters.currency(r.returns_pending, decimals: false))
                    statLine("Received", Formatters.currency(r.returns_received, decimals: false))
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.border, lineWidth: 1))
            }
        }
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.Colors.text)
        }
    }

    // MARK: - Goals

    private func goalsSection(_ goals: [RecapGoal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GOALS").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.Colors.textMuted).tracking(1)
            ForEach(goals) { goal in
                HStack(spacing: 10) {
                    let color: Color = goal.progress >= 1 ? Theme.Colors.success : goal.progress > 0.5 ? Theme.Colors.accent : Theme.Colors.textMuted
                    RingGaugeView(value: goal.currentAmount, maxValue: goal.targetAmount, size: 36, strokeWidth: 3.5, color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.text).lineLimit(1)
                        Text("\(Formatters.currency(goal.currentAmount, decimals: false)) / \(Formatters.currency(goal.targetAmount, decimals: false))")
                            .font(.system(size: 10)).foregroundColor(Theme.Colors.textMuted)
                    }
                    Spacer()
                    Text("\(Int(goal.progress * 100))%").font(.system(size: 11, weight: .semibold)).foregroundColor(color)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Spreads

    private func spreadsSection(_ spreads: [RecapSpread]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYOFFS").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.Colors.textMuted).tracking(1)
            ForEach(spreads) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.description).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.text).lineLimit(1)
                        Text("\(s.monthsRemaining) months left").font(.system(size: 10)).foregroundColor(Theme.Colors.textMuted)
                    }
                    Spacer()
                    Text("\(Formatters.currency(s.monthlyPortion, decimals: false))/mo")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.Colors.rose)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func metricColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundColor(Theme.Colors.textMuted)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func allocationIcon(_ type: String) -> String {
        switch type {
        case "spread_paydown": return "creditcard.fill"
        case "goal_contribution": return "target"
        case "next_month_boost": return "arrow.right.circle.fill"
        case "bank_it": return "building.columns.fill"
        case "goal_reduction": return "arrow.down.right.circle.fill"
        case "next_month_reduce": return "arrow.left.circle.fill"
        case "absorb_deficit": return "hand.raised.fill"
        default: return "circle"
        }
    }

    private func allocationTargetLabel(_ alloc: RecapAllocation) -> String {
        if let goalId = alloc.target_goal_id {
            return goalOptions.first(where: { $0.id == goalId })?.name ?? "Goal"
        }
        if let txId = alloc.target_transaction_id {
            return spreadOptions.first(where: { $0.id == txId })?.description ?? "Spread"
        }
        if alloc.allocation_type == "next_month_reduce" { return "Payoff next month" }
        switch alloc.allocation_type {
        case "spread_paydown": return "Pay Down Spread"
        case "goal_contribution": return "Fund a Goal"
        case "next_month_boost": return "Boost Next Month"
        case "bank_it": return "Bank It"
        case "goal_reduction": return "Reduce a Goal"
        case "absorb_deficit": return "Take the Hit"
        default: return alloc.allocation_type
        }
    }

    // MARK: - API

    private func loadRecap() {
        Task {
            do {
                let response: RecapResponse = try await APIClient.shared.request(
                    "/api/recap?month=\(month)&type=\(recapType)"
                )
                recap = response.recap
                allocations = response.allocations ?? []
                goalOptions = response.options?.goals ?? []
                spreadOptions = response.options?.spreads ?? []
            } catch {
                // If specific type not found, try the other
                recap = nil
            }
            loading = false
        }
    }

    private func regenerateRecap() {
        regenerating = true
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/recap/generate",
                    method: "POST",
                    body: ["month": month, "recap_type": recapType, "force": true]
                )
                loading = true
                loadRecap()
                toastSuccess = "Recap regenerated"
            } catch {
                toastError = "Failed to regenerate"
            }
            regenerating = false
        }
    }

    private func generateRecap() {
        generating = true
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/recap/generate",
                    method: "POST",
                    body: ["month": month, "recap_type": recapType]
                )
                loading = true
                loadRecap()
                toastSuccess = "Recap generated"
            } catch {
                toastError = "Failed to generate recap"
            }
            generating = false
        }
    }
}

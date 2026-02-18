import SwiftUI

struct MonthlyRecapView: View {
    let month: String
    var recapType: String = "monthly"
    let onDismiss: () -> Void
    @State private var recap: RecapData?
    @State private var allocations: [RecapAllocation] = []
    @State private var goalOptions: [AllocationGoalOption] = []
    @State private var spreadOptions: [AllocationSpreadOption] = []
    @State private var loading = true
    @State private var markedViewed = false
    @State private var regenerating = false

    // Allocation UI state
    @State private var activePicker: String? = nil // allocation_type currently being configured
    @State private var pickerTarget: Int? = nil
    @State private var pickerAmount: String = ""
    @State private var allocating = false
    @State private var undoingId: Int? = nil
    @State private var needsAllocReset = false

    private var isMidMonth: Bool { (recap?.recap_type ?? recapType) == "mid_month" }
    private var isSurplus: Bool { (recap?.surplus_deficit ?? 0) > 0 }
    private var isDeficit: Bool { (recap?.surplus_deficit ?? 0) < 0 }
    private var surplusColor: Color {
        isSurplus ? Theme.Colors.success : isDeficit ? Theme.Colors.error : Theme.Colors.textSecondary
    }

    private var totalAmount: Double { abs(recap?.surplus_deficit ?? 0) }
    private var allocatedAmount: Double { allocations.reduce(0) { $0 + $1.amount } }
    private var remainingAmount: Double { max(totalAmount - allocatedAmount, 0) }
    private var isFullyAllocated: Bool { remainingAmount < 0.01 }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let recap = recap {
                    ScrollView {
                        VStack(spacing: 24) {
                            heroSection(recap)

                            if isMidMonth, let mm = recap.mid_month_metrics {
                                midMonthPaceSection(recap, metrics: mm)
                            }

                            // Allocation section right after hero, above "WHERE IT WENT"
                            if !isMidMonth && abs(recap.surplus_deficit) >= 1 {
                                allocationSection(recap)
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
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.Colors.textDisabled)
                        Text("No recap available")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        regenerateRecap()
                    } label: {
                        if regenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                        }
                    }
                    .disabled(regenerating)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .onAppear { loadRecap() }
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
                Text(monthLabel.uppercased())
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

            if let regen = r.regenerated_at, !regen.isEmpty {
                Text("Regenerated")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.textDisabled)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 24)
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
                metricColumn(
                    label: "Avg/Day",
                    value: Formatters.currency(mm.dailyAverageSpend, decimals: false),
                    color: Theme.Colors.text
                )
                metricColumn(
                    label: "Need/Day",
                    value: Formatters.currency(max(mm.dailyBudgetNeeded, 0), decimals: false),
                    color: paceColor
                )
                metricColumn(
                    label: "Projected",
                    value: Formatters.currency(mm.projectedMonthTotal, decimals: false),
                    color: mm.projectedMonthTotal <= r.flexible_budget ? Theme.Colors.success : Theme.Colors.error
                )
            }
        }
        .cardStyle()
    }

    private func metricColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textMuted)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Allocation

    private func allocationSection(_ r: RecapData) -> some View {
        VStack(spacing: 12) {
            // Header with amount
            HStack(spacing: 6) {
                Image(systemName: isSurplus ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(surplusColor)
                    .font(.system(size: 16))
                Text("\(Formatters.currency(totalAmount, decimals: false)) \(isSurplus ? "surplus" : "over budget")")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(surplusColor)
            }

            // Show existing allocations
            if !allocations.isEmpty {
                VStack(spacing: 6) {
                    ForEach(allocations) { alloc in
                        allocationRow(alloc)
                    }
                }
            }

            // Remaining indicator or complete badge
            if isFullyAllocated {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.success)
                        .font(.system(size: 14))
                    Text("Fully allocated")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.success)
                }
                .padding(.top, 4)
            } else {
                if !allocations.isEmpty {
                    HStack {
                        Text("Remaining")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)
                        Spacer()
                        Text(Formatters.currency(remainingAmount, decimals: false))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(surplusColor)
                    }
                    .padding(.top, 2)
                }

                // Active picker or type buttons
                if let active = activePicker {
                    allocationPickerView(active)
                } else {
                    allocationButtons()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }

    private func allocationButtons() -> some View {
        VStack(spacing: 8) {
            if isSurplus {
                HStack(spacing: 8) {
                    allocButton("Pay Down Spread", icon: "creditcard.fill", type: "spread_paydown", disabled: spreadOptions.isEmpty)
                    allocButton("Fund a Goal", icon: "target", type: "goal_contribution", disabled: goalOptions.isEmpty)
                }
                HStack(spacing: 8) {
                    allocButton("Boost Next Month", icon: "arrow.right.circle.fill", type: "next_month_boost")
                    allocButton("Bank It", icon: "building.columns.fill", type: "bank_it")
                }
            } else {
                HStack(spacing: 8) {
                    allocButton("Reduce a Goal", icon: "arrow.down.right.circle.fill", type: "goal_reduction", disabled: goalOptions.isEmpty)
                    allocButton("Tighten Next Month", icon: "arrow.left.circle.fill", type: "next_month_reduce")
                }
                HStack(spacing: 8) {
                    allocButton("Take the Hit", icon: "hand.raised.fill", type: "absorb_deficit")
                    Color.clear.frame(height: 0)
                }
            }
        }
        .padding(.top, 4)
    }

    private func allocButton(_ label: String, icon: String, type: String, disabled: Bool = false) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                // For types that don't need a target, just allocate the remaining amount
                if type == "bank_it" || type == "absorb_deficit" || type == "next_month_reduce" {
                    submitAllocation(type: type, targetGoalId: nil, targetTransactionId: nil, amount: remainingAmount)
                } else if type == "next_month_boost" {
                    pickerAmount = String(format: "%.2f", remainingAmount)
                    pickerTarget = nil
                    activePicker = type
                } else {
                    pickerAmount = String(format: "%.2f", remainingAmount)
                    pickerTarget = nil
                    activePicker = type
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(disabled ? Theme.Colors.textDisabled : Theme.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(disabled ? Theme.Colors.subtleBg : Theme.Colors.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(disabled ? Theme.Colors.border : Theme.Colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(disabled)
    }

    private func allocationPickerView(_ type: String) -> some View {
        VStack(spacing: 10) {
            // Header with type label and cancel
            HStack {
                Text(allocationLabel(type))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.text)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activePicker = nil
                        pickerTarget = nil
                        pickerAmount = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textMuted)
                        .font(.system(size: 16))
                }
            }

            // Target picker for types that need one
            if type == "spread_paydown" {
                ForEach(spreadOptions) { spread in
                    Button {
                        pickerTarget = spread.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spread.description)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.Colors.text)
                                    .lineLimit(1)
                                Text("\(Formatters.currency(spread.monthlyPortion, decimals: false))/mo \u{2022} \(spread.monthsRemaining) left")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                            Spacer()
                            if pickerTarget == spread.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.accent)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(pickerTarget == spread.id ? Theme.Colors.accent.opacity(0.06) : Theme.Colors.subtleBg)
                        )
                    }
                }
            } else if type == "goal_contribution" || type == "goal_reduction" {
                ForEach(goalOptions) { goal in
                    Button {
                        pickerTarget = goal.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.Colors.text)
                                    .lineLimit(1)
                                Text("\(Formatters.currency(goal.currentAmount, decimals: false)) / \(Formatters.currency(goal.targetAmount, decimals: false))")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                            Spacer()
                            if pickerTarget == goal.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.accent)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(pickerTarget == goal.id ? Theme.Colors.accent.opacity(0.06) : Theme.Colors.subtleBg)
                        )
                    }
                }
            }

            // Amount input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("Amount", text: $pickerAmount)
                    .font(.system(size: 14))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)

                Button {
                    pickerAmount = String(format: "%.2f", remainingAmount)
                } label: {
                    Text("Max")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accent.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.Colors.subtleBg)
            )

            // Submit button
            let needsTarget = type == "spread_paydown" || type == "goal_contribution" || type == "goal_reduction"
            let canSubmit = (!needsTarget || pickerTarget != nil) && (Double(pickerAmount) ?? 0) > 0

            Button {
                guard let amt = Double(pickerAmount), amt > 0 else { return }
                let goalId = (type == "goal_contribution" || type == "goal_reduction") ? pickerTarget : nil
                let txId = type == "spread_paydown" ? pickerTarget : nil
                submitAllocation(type: type, targetGoalId: goalId, targetTransactionId: txId, amount: amt)
            } label: {
                HStack(spacing: 6) {
                    if allocating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    }
                    Text("Allocate")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(canSubmit ? Theme.Colors.accent : Theme.Colors.textDisabled)
                )
            }
            .disabled(!canSubmit || allocating)
        }
        .padding(.top, 4)
    }

    private func allocationRow(_ alloc: RecapAllocation) -> some View {
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

            Button {
                undoAllocation(alloc)
            } label: {
                if undoingId == alloc.id {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Text("Undo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.error)
                }
            }
            .disabled(undoingId != nil)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.subtleBg)
        )
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
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                Spacer()
                Text(Formatters.currency(amount, decimals: false))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.subtleBg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
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
                        Circle()
                            .fill(Color(hex: cat.color))
                            .frame(width: 8, height: 8)
                        Text(cat.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.text)
                            .lineLimit(1)
                        Spacer()
                        Text(Formatters.currency(cat.amount, decimals: false))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.Colors.subtleBg)
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: cat.color).opacity(0.6))
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
            Text("NET CASH")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            if let checking = r.net_cash_checking {
                HStack {
                    Text("Checking")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(Formatters.currency(checking, decimals: false))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.text)
                }
            }
            if let credit = r.net_cash_credit_debt {
                HStack {
                    Text("Credit Debt")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(Formatters.currency(credit, decimals: false))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(credit < 0 ? Theme.Colors.error : Theme.Colors.text)
                }
            }
            Divider()
            if let total = r.net_cash_total {
                HStack {
                    Text("Net Total")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.text)
                    Spacer()
                    Text(Formatters.currency(total, decimals: false))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(total >= 0 ? Theme.Colors.success : Theme.Colors.error)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Healthcare & Returns

    private func healthcareReturnsSection(_ r: RecapData) -> some View {
        HStack(spacing: 12) {
            if r.healthcare_paid > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HEALTHCARE")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textMuted)
                        .tracking(1)
                    statLine("Paid", Formatters.currency(r.healthcare_paid, decimals: false))
                    statLine("Awaiting", Formatters.currency(r.healthcare_pending, decimals: false))
                    statLine("Reimbursed", Formatters.currency(r.healthcare_reimbursed, decimals: false))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }

            if r.returns_pending > 0 || r.returns_received > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RETURNS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textMuted)
                        .tracking(1)
                    statLine("Awaiting", Formatters.currency(r.returns_pending, decimals: false))
                    statLine("Received", Formatters.currency(r.returns_received, decimals: false))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }
        }
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.text)
        }
    }

    // MARK: - Goals

    private func goalsSection(_ goals: [RecapGoal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GOALS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            ForEach(goals) { goal in
                HStack(spacing: 10) {
                    let color: Color = goal.progress >= 1 ? Theme.Colors.success : goal.progress > 0.5 ? Theme.Colors.accent : Theme.Colors.textMuted
                    RingGaugeView(
                        value: goal.currentAmount,
                        maxValue: goal.targetAmount,
                        size: 36,
                        strokeWidth: 3.5,
                        color: color
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.text)
                            .lineLimit(1)
                        Text("\(Formatters.currency(goal.currentAmount, decimals: false)) / \(Formatters.currency(goal.targetAmount, decimals: false))")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                    }

                    Spacer()

                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Spreads

    private func spreadsSection(_ spreads: [RecapSpread]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYOFFS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            ForEach(spreads) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.text)
                            .lineLimit(1)
                        Text("\(s.monthsRemaining) months left")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    Spacer()
                    Text("\(Formatters.currency(s.monthlyPortion, decimals: false))/mo")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.rose)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Allocation Helpers

    private func allocationLabel(_ type: String) -> String {
        switch type {
        case "spread_paydown": return "Pay Down Spread"
        case "goal_contribution": return "Fund a Goal"
        case "next_month_boost": return "Boost Next Month"
        case "bank_it": return "Bank It"
        case "goal_reduction": return "Reduce a Goal"
        case "next_month_reduce": return "Tighten Next Month"
        case "absorb_deficit": return "Take the Hit"
        default: return type
        }
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
        return allocationLabel(alloc.allocation_type)
    }

    // MARK: - API Calls

    private func loadRecap() {
        Task {
            do {
                let typeParam = recapType == "mid_month" ? "&type=mid_month" : ""
                let response: RecapResponse = try await APIClient.shared.request(
                    "/api/recap?month=\(month)\(typeParam)"
                )
                recap = response.recap
                allocations = response.allocations ?? []
                goalOptions = response.options?.goals ?? []
                spreadOptions = response.options?.spreads ?? []
                // If there are existing allocations, next allocation should reset them
                // (supports second user overriding first user's choices)
                needsAllocReset = !(response.allocations ?? []).isEmpty
                // Mark as viewed
                if recap != nil && !markedViewed {
                    markedViewed = true
                    let _: OkResult = try await APIClient.shared.request(
                        "/api/recap",
                        method: "PATCH",
                        body: ["month": month, "action": "viewed", "recap_type": recapType]
                    )
                }
            } catch {
                print("Recap load error:", error)
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
                markedViewed = false
                allocations = []
                loadRecap()
            } catch {
                print("Regenerate error:", error)
            }
            regenerating = false
        }
    }

    private func submitAllocation(type: String, targetGoalId: Int?, targetTransactionId: Int?, amount: Double) {
        guard let recapId = recap?.id else { return }
        allocating = true

        var body: [String: Any] = [
            "recap_id": recapId,
            "allocation_type": type,
            "amount": min(amount, remainingAmount),
        ]
        if let gid = targetGoalId { body["target_goal_id"] = gid }
        if let tid = targetTransactionId { body["target_transaction_id"] = tid }
        if needsAllocReset {
            body["reset_existing"] = true
        }

        Task {
            do {
                let response: AllocateResponse = try await APIClient.shared.request(
                    "/api/recap/allocate",
                    method: "POST",
                    body: body
                )
                if needsAllocReset {
                    // After reset, clear old allocations and add the new one
                    needsAllocReset = false
                    allocations = []
                }
                if let newAlloc = response.allocation {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        allocations.append(newAlloc)
                        activePicker = nil
                        pickerTarget = nil
                        pickerAmount = ""
                    }
                }
            } catch {
                print("Allocate error:", error)
            }
            allocating = false
        }
    }

    private func undoAllocation(_ alloc: RecapAllocation) {
        undoingId = alloc.id
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/recap/allocate",
                    method: "DELETE",
                    body: ["allocation_id": alloc.id]
                )
                withAnimation(.easeInOut(duration: 0.2)) {
                    allocations.removeAll { $0.id == alloc.id }
                }
            } catch {
                print("Undo error:", error)
            }
            undoingId = nil
        }
    }

    // MARK: - Helpers

    private var monthLabel: String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), let y = Int(parts[0]),
              m >= 1, m <= 12 else { return month }
        let months = ["January","February","March","April","May","June",
                      "July","August","September","October","November","December"]
        return "\(months[m-1]) \(y)"
    }
}

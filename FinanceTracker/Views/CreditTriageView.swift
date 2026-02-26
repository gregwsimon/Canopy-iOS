import SwiftUI

struct CreditTriageView: View {
    let month: String
    var onAllocated: (() -> Void)?

    @State private var credits: [CreditItem] = []
    @State private var allocatedCredits: [CreditItem] = []
    @State private var goals: [GoalOption] = []
    @State private var expenseCategories: [Category] = []
    @State private var pendingReturns: [ReturnItem] = []
    @State private var spreadItems: [SpreadItem] = []
    @State private var loading = true
    @State private var activeCredit: Int? = nil
    @State private var actionMode: ActionMode? = nil
    @State private var allocating = false
    @State private var showAllAllocated = false

    // Sheet states
    @State private var showTransactionFinder = false
    @State private var finderType = "return"
    @State private var showAmountSheet = false
    @State private var pendingAllocation: PendingAllocation? = nil
    @State private var categorySearch = ""
    @State private var revertingId: Int? = nil
    @State private var allocationToRevert: CreditSubAllocation? = nil
    @State private var toastError: String? = nil
    @State private var toastSuccess: String? = nil

    enum ActionMode {
        case offset, goal, income
    }

    struct PendingAllocation {
        let creditId: Int
        let action: String
        let targetTransaction: SearchTransaction?
        let targetCategory: Category?
        let targetGoal: GoalOption?
    }

    private var totalUnallocated: Double {
        credits.reduce(0) { $0 + ($1.remainingAmount ?? $1.amount) }
    }

    private var totalAllocated: Double {
        allocatedCredits.reduce(0) { $0 + $1.amount }
    }

    private var triageProgress: Double {
        let total = totalUnallocated + totalAllocated
        guard total > 0 else { return 1.0 }
        return totalAllocated / total
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header: "$X to allocate · N credits" + progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Formatters.currency(totalUnallocated))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(credits.isEmpty && !loading ? Theme.Colors.textMuted : Theme.Colors.success)
                        Text("to allocate")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("·")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text("\(credits.count) credit\(credits.count == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Theme.Colors.divider)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Theme.Colors.success)
                                .frame(width: geo.size.width * triageProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Unallocated credits
                if loading {
                    ProgressView()
                        .padding(.top, 40)
                        .padding(.bottom, 40)
                } else if credits.isEmpty {
                    // "All caught up" empty state
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.success.opacity(0.08))
                                .frame(width: 48, height: 48)
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Theme.Colors.success)
                        }
                        Text("All caught up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 32)
                } else {
                    VStack(spacing: 12) {
                        ForEach(credits) { credit in
                            creditRow(credit)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Allocated section (inline, below unallocated)
                if !loading && !allocatedCredits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        // Section header
                        HStack {
                            Text("Allocated · \(allocatedCredits.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.textMuted)
                            Spacer()
                            if allocatedCredits.count > 3 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAllAllocated.toggle()
                                    }
                                } label: {
                                    Text(showAllAllocated ? "Show less" : "See all ›")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.textMuted)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Compact allocated rows
                        let displayedCredits = showAllAllocated ? allocatedCredits : Array(allocatedCredits.prefix(3))
                        VStack(spacing: 0) {
                            ForEach(displayedCredits) { credit in
                                Button {
                                    if let alloc = credit.allocations?.first {
                                        allocationToRevert = alloc
                                    }
                                } label: {
                                    allocatedCompactRow(credit)
                                }
                                .buttonStyle(.plain)
                                if credit.id != displayedCredits.last?.id {
                                    Divider()
                                        .padding(.horizontal, 14)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Theme.Colors.background)
        .toastError($toastError)
        .toastSuccess($toastSuccess)
        .navigationTitle("Credit Triage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
        .alert("Revert Allocation",
               isPresented: Binding(
                   get: { allocationToRevert != nil },
                   set: { if !$0 { allocationToRevert = nil } }
               )
        ) {
            Button("Revert", role: .destructive) {
                if let alloc = allocationToRevert {
                    revertAllocation(alloc)
                }
            }
            Button("Cancel", role: .cancel) {
                allocationToRevert = nil
            }
        } message: {
            if let alloc = allocationToRevert {
                Text("Undo → \(alloc.label ?? alloc.type) \(Formatters.currency(alloc.amount))? This will move the credit back to unallocated.")
            }
        }
        .sheet(isPresented: $showTransactionFinder) {
            if let creditId = activeCredit, let credit = credits.first(where: { $0.id == creditId }) {
                TransactionFinderSheet(
                    type: finderType,
                    creditAmount: credit.remainingAmount ?? credit.amount,
                    categories: expenseCategories,
                    credit: credit,
                    onAllocated: { tx, amount in
                        let action = finderType == "healthcare" ? "healthcare" : "return"
                        performAllocation(
                            creditId: creditId,
                            action: action,
                            amount: amount,
                            extra: ["original_id": tx.id]
                        )
                    }
                )
            }
        }
        .sheet(isPresented: $showAmountSheet) {
            if let pending = pendingAllocation,
               let credit = credits.first(where: { $0.id == pending.creditId }) {
                AllocationAmountSheet(
                    credit: credit,
                    action: pending.action,
                    targetTransaction: pending.targetTransaction,
                    targetCategory: pending.targetCategory,
                    targetGoal: pending.targetGoal,
                    onAllocate: { amount in
                        performAllocation(
                            creditId: pending.creditId,
                            action: pending.action,
                            amount: amount,
                            extra: buildExtra(pending)
                        )
                    }
                )
            }
        }
    }

    // MARK: - Row Views

    /// Compact row for the inline allocated section
    private func allocatedCompactRow(_ credit: CreditItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(credit.description ?? "Credit")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
                if let allocations = credit.allocations, let first = allocations.first {
                    Text(first.label ?? first.type)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.divider)
                        .cornerRadius(4)
                }
            }
            Spacer()
            Text(Formatters.currency(credit.amount))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func creditRow(_ credit: CreditItem) -> some View {
        let remaining = credit.remainingAmount ?? credit.amount
        let hasAllocations = (credit.allocations ?? []).isEmpty == false

        VStack(alignment: .leading, spacing: 10) {
            // Credit info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(credit.description ?? "Credit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.text)
                    HStack(spacing: 6) {
                        Text(Formatters.shortDate(credit.date))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)
                        if let acct = credit.accountName {
                            Text(acct)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(Formatters.currency(credit.amount))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.success)
                    if hasAllocations {
                        Text("\(Formatters.currency(remaining)) left")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.flowCredits)
                    }
                }
            }

            // Existing allocations chips
            if hasAllocations {
                allocationChips(credit.allocations ?? [])
            }

            // Progress bar for partial allocations
            if hasAllocations {
                let progress = (credit.allocatedAmount ?? 0) / credit.amount
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.border)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.flowSavings)
                            .frame(width: geo.size.width * min(progress, 1.0), height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Action area
            if activeCredit == credit.id {
                actionPicker(for: credit)
            } else {
                actionButtons(for: credit)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.border, lineWidth: 1))
    }

    private func allocationChips(_ allocations: [CreditSubAllocation]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(allocations) { alloc in
                    let color = colorForAllocType(alloc.type)
                    HStack(spacing: 3) {
                        Text("→")
                            .font(.system(size: 10))
                        Text("\(alloc.label ?? alloc.type) \(Formatters.currency(alloc.amount))")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: color))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: color).opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
    }

    private func revertableAllocationChips(_ allocations: [CreditSubAllocation]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(allocations) { alloc in
                    let color = colorForAllocType(alloc.type)
                    Button {
                        allocationToRevert = alloc
                    } label: {
                        HStack(spacing: 3) {
                            Text("→")
                                .font(.system(size: 10))
                            Text("\(alloc.label ?? alloc.type) \(Formatters.currency(alloc.amount))")
                                .font(.system(size: 12, weight: .medium))
                            if revertingId == alloc.id {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .opacity(0.5)
                            }
                        }
                        .foregroundColor(Color(hex: color))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: color).opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(revertingId != nil)
                }
            }
        }
    }

    private func colorForAllocType(_ type: String) -> String {
        switch type {
        case "category_offset": return "#7b93c9" // flowFlex
        case "spread_offset": return "#8e8e93"   // flowFixed
        case "goal": return "#3d8b80"             // flowSavings
        case "income": return "#6b9e78"           // flowIncome
        case "return": return "#7ec8d4"           // flowPayoff
        case "healthcare": return "#c49a6c"       // flowCredits
        default: return "#666"
        }
    }

    @ViewBuilder
    private func actionButtons(for credit: CreditItem) -> some View {
        VStack(spacing: 8) {
            triageActionButton("It's income", color: Theme.Colors.flowIncome) {
                activeCredit = credit.id
                actionMode = .income
            }
            triageActionButton("It's a return", color: Theme.Colors.flowPayoff) {
                activeCredit = credit.id
                finderType = "return"
                showTransactionFinder = true
            }
            triageActionButton("Offset spending", color: Theme.Colors.flowFlex) {
                activeCredit = credit.id
                actionMode = .offset
            }
            triageActionButton("Healthcare reimburse", color: Theme.Colors.flowCredits) {
                activeCredit = credit.id
                finderType = "healthcare"
                showTransactionFinder = true
            }
            triageActionButton("Add to goal", color: Theme.Colors.flowSavings) {
                activeCredit = credit.id
                actionMode = .goal
            }
        }
    }

    private func triageActionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 20)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
        }
        .disabled(allocating)
    }

    @ViewBuilder
    private func actionPicker(for credit: CreditItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch actionMode {
            case .offset:
                Text("Offset which expense?")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)

                // Spread expenses section
                if !spreadItems.isEmpty {
                    Text("Spread expenses")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.flowFixed.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.top, 4)

                    ForEach(spreadItems) { item in
                        Button {
                            pendingAllocation = PendingAllocation(
                                creditId: credit.id,
                                action: "spread_offset",
                                targetTransaction: SearchTransaction(
                                    id: item.id,
                                    date: item.startMonth + "-01",
                                    amount: -item.totalAmount,
                                    description: item.description,
                                    categoryName: item.categoryName,
                                    accountName: nil,
                                    isReturn: nil,
                                    returnStatus: nil,
                                    returnedAmount: nil,
                                    isHealthcare: nil,
                                    reimbursementStatus: nil,
                                    reimbursedAmount: nil,
                                    remainingAmount: nil
                                ),
                                targetCategory: nil,
                                targetGoal: nil
                            )
                            activeCredit = nil
                            actionMode = nil
                            showAmountSheet = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.description)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.Colors.text)
                                    Text(item.categoryName)
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textMuted)
                                }
                                Spacer()
                                Text(Formatters.currency(item.monthlyPortion) + "/mo")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.Colors.flowFixed)
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                        }
                        .disabled(allocating)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("Categories")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(.horizontal, 10)
                }

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                    TextField("Search categories...", text: $categorySearch)
                        .font(.system(size: 12))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !categorySearch.isEmpty {
                        Button { categorySearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.Colors.divider)
                .cornerRadius(6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedCategories, id: \.parent.id) { group in
                            // Parent header
                            Text(group.parent.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.top, 10)
                                .padding(.bottom, 2)

                            if group.children.isEmpty {
                                // Standalone category (no children) — parent is tappable
                                categoryButton(credit: credit, cat: group.parent, indented: false)
                            } else {
                                ForEach(group.children) { child in
                                    categoryButton(credit: credit, cat: child, indented: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)

            case .goal:
                Text("Add to which goal?")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
                if goals.isEmpty {
                    Text("No active goals")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textMuted)
                } else {
                    ForEach(goals) { goal in
                        Button {
                            pendingAllocation = PendingAllocation(
                                creditId: credit.id,
                                action: "goal",
                                targetTransaction: nil,
                                targetCategory: nil,
                                targetGoal: goal
                            )
                            activeCredit = nil
                            actionMode = nil
                            showAmountSheet = true
                        } label: {
                            HStack {
                                Text(goal.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.text)
                                Spacer()
                                Text("\(Formatters.currency(goal.remaining)) left")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        }
                        .disabled(allocating)
                    }
                }

            case .income:
                Text("Classify as:")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
                Button {
                    pendingAllocation = PendingAllocation(
                        creditId: credit.id,
                        action: "other_income",
                        targetTransaction: nil,
                        targetCategory: nil,
                        targetGoal: nil
                    )
                    activeCredit = nil
                    actionMode = nil
                    showAmountSheet = true
                } label: {
                    Text("Other Income (gifts, cashback, rewards)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                }
                .disabled(allocating)
                Button {
                    pendingAllocation = PendingAllocation(
                        creditId: credit.id,
                        action: "tax_refund",
                        targetTransaction: nil,
                        targetCategory: nil,
                        targetGoal: nil
                    )
                    activeCredit = nil
                    actionMode = nil
                    showAmountSheet = true
                } label: {
                    Text("Tax Refund")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                }
                .disabled(allocating)

            case .none:
                EmptyView()
            }

            Button("Cancel") {
                activeCredit = nil
                actionMode = nil
            }
            .font(.system(size: 11))
            .foregroundColor(Theme.Colors.textMuted)
        }
    }

    // MARK: - Category Picker Helpers

    private struct CategoryGroup {
        let parent: Category
        let children: [Category]
    }

    private var groupedCategories: [CategoryGroup] {
        let query = categorySearch.lowercased()
        let parents = expenseCategories.filter { $0.parent_id == nil }

        var groups: [CategoryGroup] = []
        for parent in parents {
            let children = expenseCategories.filter { $0.parent_id == parent.id }

            if query.isEmpty {
                groups.append(CategoryGroup(parent: parent, children: children))
            } else {
                // Filter: show group if parent matches or any child matches
                let matchingChildren = children.filter { $0.name.lowercased().contains(query) }
                let parentMatches = parent.name.lowercased().contains(query)
                if parentMatches || !matchingChildren.isEmpty {
                    groups.append(CategoryGroup(
                        parent: parent,
                        children: parentMatches ? children : matchingChildren
                    ))
                }
            }
        }

        // Also include categories with no parent that aren't themselves parents
        let parentIds = Set(parents.map { $0.id })
        let standalone = expenseCategories.filter {
            $0.parent_id != nil && !parentIds.contains($0.parent_id!)
        }
        for cat in standalone {
            if query.isEmpty || cat.name.lowercased().contains(query) {
                groups.append(CategoryGroup(parent: cat, children: []))
            }
        }

        return groups
    }

    private func categoryButton(credit: CreditItem, cat: Category, indented: Bool) -> some View {
        Button {
            pendingAllocation = PendingAllocation(
                creditId: credit.id,
                action: "spend_offset",
                targetTransaction: nil,
                targetCategory: cat,
                targetGoal: nil
            )
            activeCredit = nil
            actionMode = nil
            categorySearch = ""
            showAmountSheet = true
        } label: {
            Text(cat.name)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.leading, indented ? 20 : 10)
                .padding(.trailing, 10)
        }
        .disabled(allocating)
    }

    // MARK: - Helpers

    private func buildExtra(_ pending: PendingAllocation) -> [String: Any] {
        var extra: [String: Any] = [:]
        if let tx = pending.targetTransaction {
            extra["original_id"] = tx.id
        }
        if let cat = pending.targetCategory {
            extra["category_id"] = cat.id
        }
        if let goal = pending.targetGoal {
            extra["goal_id"] = goal.id
        }
        // spread_offset needs original_id but no category_id
        return extra
    }

    // MARK: - API

    func loadData() {
        Task {
            do {
                let response: UnallocatedCreditsResponse = try await APIClient.shared.request(
                    "/api/credits/unallocated?month=\(month)"
                )
                credits = response.credits
                allocatedCredits = response.allocatedCredits ?? []
                goals = response.goals
                expenseCategories = response.expenseCategories
                pendingReturns = response.pendingReturns
                spreadItems = response.spreadItems ?? []
            } catch {
                toastError = "Failed to load credits"
            }
            loading = false
        }
    }

    func performAllocation(creditId: Int, action: String, amount: Double, extra: [String: Any] = [:]) {
        allocating = true
        Task {
            do {
                var body: [String: Any] = [
                    "credit_id": creditId,
                    "action": action,
                    "amount": amount,
                ]
                for (key, value) in extra {
                    body[key] = value
                }
                let _: OkResult = try await APIClient.shared.request(
                    "/api/credits/allocate",
                    method: "POST",
                    body: body
                )
                // Optimistic UI: move credit out of unallocated immediately
                if let idx = credits.firstIndex(where: { $0.id == creditId }) {
                    let credit = credits[idx]
                    let remaining = (credit.remainingAmount ?? credit.amount) - amount
                    if remaining <= 0.01 {
                        // Fully allocated — move to allocated list
                        let moved = credits.remove(at: idx)
                        allocatedCredits.insert(moved, at: 0)
                    } else {
                        // Partial — update remaining
                        credits[idx].remainingAmount = remaining
                        credits[idx].allocatedAmount = (credit.allocatedAmount ?? 0) + amount
                    }
                }
                pendingAllocation = nil
                activeCredit = nil
                actionMode = nil
                allocating = false
                onAllocated?()
                toastSuccess = "Allocated successfully"
                // Background refresh for accurate server state
                loadData()
            } catch {
                toastError = "Allocation failed"
                allocating = false
            }
        }
    }

    func revertAllocation(_ alloc: CreditSubAllocation) {
        revertingId = alloc.id
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/credits/allocate",
                    method: "DELETE",
                    body: ["allocation_id": alloc.id]
                )
                loadData()
                onAllocated?()
                toastSuccess = "Allocation reverted"
            } catch {
                toastError = "Failed to revert allocation"
            }
            revertingId = nil
        }
    }
}

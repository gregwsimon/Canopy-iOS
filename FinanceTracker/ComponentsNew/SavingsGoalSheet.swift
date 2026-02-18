import SwiftUI

struct SavingsGoalSheet: View {
    let month: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode: GoalMode = .selection
    @State private var activeGoal: Goal?
    @State private var allGoals: [Goal] = []
    @State private var loading = true
    @State private var saving = false

    // Save This Month
    @State private var monthlyAmount = ""

    // Save Towards Goal (new goal creation)
    @State private var goalName = ""
    @State private var goalAmount = ""
    @State private var goalDeadline = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    // Pick Goal → Configure
    @State private var selectedGoal: Goal?
    @State private var savingsMethod: SavingsMethod = .fixedMonthly
    @State private var fixedAmount = ""
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    enum GoalMode {
        case selection
        case saveThisMonth
        case pickGoal
        case configureGoalSavings
        case createNewGoal
    }

    enum SavingsMethod: String, CaseIterable {
        case fixedMonthly = "Fixed Monthly"
        case targetDate = "Target Date"
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            switch mode {
                            case .selection:
                                selectionView
                            case .saveThisMonth:
                                saveThisMonthView
                            case .pickGoal:
                                pickGoalView
                            case .configureGoalSavings:
                                configureGoalSavingsView
                            case .createNewGoal:
                                createNewGoalView
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
                if mode != .selection {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
            }
        }
        .onAppear { loadGoals() }
    }

    private var navigationTitle: String {
        switch mode {
        case .selection: return "Savings Goal"
        case .saveThisMonth: return "Save This Month"
        case .pickGoal: return "Choose a Goal"
        case .configureGoalSavings: return "Configure Savings"
        case .createNewGoal: return "New Goal"
        }
    }

    private func goBack() {
        switch mode {
        case .configureGoalSavings:
            mode = .pickGoal
        case .createNewGoal:
            mode = .pickGoal
        default:
            mode = .selection
        }
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 12) {
            if let goal = activeGoal {
                activeGoalCard(goal)
            }

            GoalOptionButton(
                title: "Break Even",
                subtitle: "No savings target — aim to not overspend",
                icon: "equal.circle",
                color: Theme.Colors.textSecondary
            ) {
                clearSavingsTarget()
            }

            GoalOptionButton(
                title: "Save This Month",
                subtitle: "Set aside a specific amount this month",
                icon: "dollarsign.circle",
                color: Theme.Colors.teal
            ) {
                mode = .saveThisMonth
            }

            GoalOptionButton(
                title: "Save Towards Goal",
                subtitle: "Pick an existing goal or create a new one",
                icon: "flag.circle",
                color: Theme.Colors.accent
            ) {
                mode = .pickGoal
            }
        }
    }

    private func activeGoalCard(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.teal)
                Text("Saving")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.teal)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button("Clear") {
                    clearSavingsTarget()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.error)
            }

            Text(goal.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.text)

            HStack(spacing: 16) {
                if goal.goalType == "monthly_savings" {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(Formatters.currency(goal.targetAmount, decimals: false))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.text)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(Formatters.currency(goal.targetAmount, decimals: false))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.text)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(Formatters.currency(goal.currentAmount, decimals: false))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.Colors.success)
                    }
                }
                if let deadline = goal.deadline {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.goalType == "monthly_savings" ? "Month" : "Deadline")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(Formatters.monthLabel(deadline))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.text)
                    }
                }
                if goal.goalType == "fund_target", let deadline = goal.deadline {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Per Month")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(Formatters.currency(computeMonthly(goal.targetAmount - goal.currentAmount, deadline: deadline), decimals: false))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.teal)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.Colors.tealBg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.Colors.teal.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Save This Month

    private var saveThisMonthView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How much do you want to save this month?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.text)

            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("0", text: $monthlyAmount)
                    .font(.system(size: 20, weight: .medium))
                    .keyboardType(.numberPad)
                    .foregroundColor(Theme.Colors.text)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )

            Text("This amount will be deducted from your flexible budget for \(Formatters.monthLabel(month)).")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)

            Button {
                saveMonthlyGoal()
            } label: {
                Text(saving ? "Saving..." : "Set Goal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(validMonthlyAmount ? .white : Theme.Colors.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(validMonthlyAmount ? Theme.Colors.teal : Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(validMonthlyAmount ? Color.clear : Theme.Colors.border, lineWidth: 1)
                    )
            }
            .disabled(!validMonthlyAmount || saving)
        }
    }

    private var validMonthlyAmount: Bool {
        guard let amount = Double(monthlyAmount) else { return false }
        return amount > 0
    }

    // MARK: - Pick Goal View

    private var pickGoalView: some View {
        VStack(spacing: 12) {
            if allGoals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.textDisabled)
                    Text("No goals yet")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("Create a goal to start saving towards it")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(allGoals) { goal in
                    goalRow(goal)
                }
            }

            // Create New Goal button
            Button {
                mode = .createNewGoal
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.accent)
                    Text("Create New Goal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textDisabled)
                }
                .padding(12)
                .cardStyle()
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let isCurrent = goal.isSavingsTarget == true
        let progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0

        return Button {
            selectedGoal = goal
            if goal.goalType == "monthly_savings" {
                savingsMethod = .fixedMonthly
                fixedAmount = String(format: "%.0f", goal.targetAmount)
            } else if goal.goalType == "fund_target", let deadline = goal.deadline {
                savingsMethod = .targetDate
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: deadline) {
                    targetDate = date
                }
            }
            mode = .configureGoalSavings
        } label: {
            HStack(spacing: 10) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.border, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min(progress, 1))
                        .stroke(Theme.Colors.teal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(goal.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.text)
                        if isCurrent {
                            Text("Active")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Theme.Colors.teal)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Theme.Colors.tealBg)
                                .cornerRadius(3)
                        }
                    }
                    Text("\(Formatters.currency(goal.currentAmount, decimals: false)) of \(Formatters.currency(goal.targetAmount, decimals: false))")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.teal)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textDisabled)
                }
            }
            .padding(12)
            .background(isCurrent ? Theme.Colors.tealBg : Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isCurrent ? Theme.Colors.teal.opacity(0.3) : Theme.Colors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Configure Goal Savings

    private var configureGoalSavingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let goal = selectedGoal {
                // Goal summary header
                HStack(spacing: 10) {
                    let progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0
                    ZStack {
                        Circle()
                            .stroke(Theme.Colors.border, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: min(progress, 1))
                            .stroke(Theme.Colors.teal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.text)
                        let remaining = goal.targetAmount - goal.currentAmount
                        Text("\(Formatters.currency(remaining, decimals: false)) remaining")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    Spacer()
                }
                .padding(12)
                .cardStyle()

                // Savings method picker
                Text("How do you want to save?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Colors.text)

                Picker("Method", selection: $savingsMethod) {
                    ForEach(SavingsMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                if savingsMethod == .fixedMonthly {
                    fixedMonthlyConfig(goal)
                } else {
                    targetDateConfig(goal)
                }

                // Save button
                Button {
                    saveGoalSavings(goal)
                } label: {
                    Text(saving ? "Saving..." : "Set as Savings Target")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(validGoalConfig ? .white : Theme.Colors.textDisabled)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(validGoalConfig ? Theme.Colors.accent : Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(validGoalConfig ? Color.clear : Theme.Colors.border, lineWidth: 1)
                        )
                }
                .disabled(!validGoalConfig || saving)
            }
        }
    }

    private func fixedMonthlyConfig(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save each month")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("0", text: $fixedAmount)
                    .font(.system(size: 20, weight: .medium))
                    .keyboardType(.numberPad)
                    .foregroundColor(Theme.Colors.text)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )

            if let amount = Double(fixedAmount), amount > 0 {
                let remaining = goal.targetAmount - goal.currentAmount
                let months = remaining > 0 ? Int(ceil(remaining / amount)) : 0
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(Theme.Colors.teal)
                        .font(.system(size: 12))
                    Text("~\(months) months to reach goal")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(10)
                .background(Theme.Colors.tealBg)
                .cornerRadius(8)
            }
        }
    }

    private func targetDateConfig(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reach goal by")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textMuted)

            HStack {
                Text("Target Date")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                DatePicker("", selection: $targetDate, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )

            let remaining = goal.targetAmount - goal.currentAmount
            let months = max(monthsUntil(targetDate), 1)
            let monthly = remaining > 0 ? remaining / Double(months) : 0

            if monthly > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(Theme.Colors.teal)
                        .font(.system(size: 12))
                    Text("\(Formatters.currency(monthly, decimals: false))/month")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.teal)
                    Text("for \(months) months")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(10)
                .background(Theme.Colors.tealBg)
                .cornerRadius(8)
            }
        }
    }

    private var validGoalConfig: Bool {
        if savingsMethod == .fixedMonthly {
            guard let amount = Double(fixedAmount), amount > 0 else { return false }
            return true
        } else {
            return targetDate > Date()
        }
    }

    // MARK: - Create New Goal View

    private var createNewGoalView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What are you saving for?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.text)

            TextField("Goal name", text: $goalName)
                .font(.system(size: 14))
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )

            Text("How much?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.text)

            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("0", text: $goalAmount)
                    .font(.system(size: 20, weight: .medium))
                    .keyboardType(.numberPad)
                    .foregroundColor(Theme.Colors.text)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )

            Button {
                createGoalAndConfigure()
            } label: {
                Text(saving ? "Creating..." : "Create Goal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(validNewGoal ? .white : Theme.Colors.textDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(validNewGoal ? Theme.Colors.accent : Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(validNewGoal ? Color.clear : Theme.Colors.border, lineWidth: 1)
                    )
            }
            .disabled(!validNewGoal || saving)
        }
    }

    private var validNewGoal: Bool {
        guard let amount = Double(goalAmount), amount > 0, !goalName.isEmpty else { return false }
        return true
    }

    // MARK: - API Calls

    private func loadGoals() {
        Task {
            do {
                let response: GoalsResponse = try await APIClient.shared.request("/api/goals")
                allGoals = response.goals
                activeGoal = response.goals.first(where: { $0.isSavingsTarget == true })
            } catch {
                print("Load goals error:", error)
            }
            loading = false
        }
    }

    private func clearSavingsTarget() {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/goals",
                    method: "PATCH",
                    body: ["clearSavingsTargets": true]
                )
                activeGoal = nil
                onSave()
                dismiss()
            } catch {
                print("Clear savings target error:", error)
            }
        }
    }

    private func saveMonthlyGoal() {
        guard let amount = Double(monthlyAmount) else { return }
        saving = true

        Task {
            let parts = month.split(separator: "-")
            guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return }
            let lastDay = Calendar.current.range(of: .day, in: .month, for: {
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                return Calendar.current.date(from: comps) ?? Date()
            }())?.count ?? 28
            let deadline = "\(y)-\(String(format: "%02d", m))-\(String(format: "%02d", lastDay))"

            do {
                let _: GoalResponse = try await APIClient.shared.request(
                    "/api/goals",
                    method: "POST",
                    body: [
                        "name": "Save \(Formatters.monthLabel(month))",
                        "goalType": "monthly_savings",
                        "targetAmount": amount,
                        "deadline": deadline,
                        "isSavingsTarget": true,
                    ] as [String: Any]
                )
                onSave()
                dismiss()
            } catch {
                print("Save monthly goal error:", error)
            }
            saving = false
        }
    }

    private func saveGoalSavings(_ goal: Goal) {
        saving = true
        Task {
            do {
                if savingsMethod == .fixedMonthly {
                    guard let amount = Double(fixedAmount) else { return }
                    let _: GoalResponse = try await APIClient.shared.request(
                        "/api/goals",
                        method: "PATCH",
                        body: [
                            "id": goal.id,
                            "goalType": "monthly_savings",
                            "targetAmount": amount,
                            "isSavingsTarget": true,
                        ] as [String: Any]
                    )
                } else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let deadlineStr = formatter.string(from: targetDate)
                    let _: GoalResponse = try await APIClient.shared.request(
                        "/api/goals",
                        method: "PATCH",
                        body: [
                            "id": goal.id,
                            "goalType": "fund_target",
                            "deadline": deadlineStr,
                            "isSavingsTarget": true,
                        ] as [String: Any]
                    )
                }
                onSave()
                dismiss()
            } catch {
                print("Save goal savings error:", error)
            }
            saving = false
        }
    }

    private func createGoalAndConfigure() {
        guard let amount = Double(goalAmount), !goalName.isEmpty else { return }
        saving = true

        Task {
            do {
                let response: GoalResponse = try await APIClient.shared.request(
                    "/api/goals",
                    method: "POST",
                    body: [
                        "name": goalName,
                        "goalType": "fund_target",
                        "targetAmount": amount,
                    ] as [String: Any]
                )
                let newGoal = Goal(
                    id: response.goal.id,
                    name: response.goal.name,
                    goalType: response.goal.goal_type,
                    targetAmount: response.goal.target_amount,
                    currentAmount: response.goal.current_amount,
                    deadline: response.goal.deadline,
                    categoryId: response.goal.category_id,
                    isSavingsTarget: false,
                    isPayoff: false
                )
                selectedGoal = newGoal
                allGoals.insert(newGoal, at: 0)
                mode = .configureGoalSavings
            } catch {
                print("Create goal error:", error)
            }
            saving = false
        }
    }

    // MARK: - Helpers

    private func computeMonthly(_ remaining: Double, deadline: String) -> Double {
        let parts = deadline.split(separator: "-")
        guard parts.count >= 2, let dY = Int(parts[0]), let dM = Int(parts[1]) else { return remaining }
        let mParts = month.split(separator: "-")
        guard mParts.count == 2, let cY = Int(mParts[0]), let cM = Int(mParts[1]) else { return remaining }
        let months = max((dY - cY) * 12 + (dM - cM), 1)
        return remaining / Double(months)
    }

    private func monthsUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.month], from: now, to: date)
        return max(comps.month ?? 1, 1)
    }
}

// MARK: - Goal Option Button

private struct GoalOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.text)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textDisabled)
            }
            .padding(12)
            .cardStyle()
        }
    }
}

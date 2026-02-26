import SwiftUI

struct GoalsView: View {
    @State private var goals: [Goal] = []
    @State private var loading = true
    @State private var showingAddSheet = false
    @State private var toastError: String? = nil
    @State private var toastSuccess: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if loading && goals.isEmpty {
                            ProgressView()
                                .padding(.top, 60)
                        } else if goals.isEmpty {
                            VStack(spacing: 12) {
                                GoalTreeView(progress: 0, size: 48)
                                Text("Plant your first goal")
                                    .font(Theme.Fonts.bodyRegular)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Every canopy starts with a single seed.")
                                    .font(Theme.Fonts.small)
                                    .foregroundColor(Theme.Colors.textMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(goals) { goal in
                                GoalDetailCard(goal: goal, onUpdate: loadGoals, onError: { toastError = $0 }, onSuccess: { toastSuccess = $0 })
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGoalSheet(onSave: loadGoals)
            }
            .toastError($toastError)
            .toastSuccess($toastSuccess)
        }
        .onAppear { loadGoals() }
    }

    func loadGoals() {
        // Show cached data instantly if available
        if goals.isEmpty, let cached: GoalsResponse = ResponseCache.shared.get("goals") {
            goals = cached.goals
            loading = false
        }
        if goals.isEmpty { loading = true }
        Task {
            do {
                let response: GoalsResponse = try await APIClient.shared.request("/api/goals")
                goals = response.goals
                ResponseCache.shared.set("goals", value: response)
            } catch {
                toastError = "Failed to load goals"
            }
            loading = false
        }
    }
}

struct GoalDetailCard: View {
    let goal: Goal
    let onUpdate: () -> Void
    var onError: ((String) -> Void)? = nil
    var onSuccess: ((String) -> Void)? = nil
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var deleting = false

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return goal.currentAmount / goal.targetAmount
    }

    private var color: Color {
        if goal.goalType == "category_limit" {
            if progress > 0.9 { return Theme.Colors.error }
            if progress > 0.75 { return Theme.Colors.warning }
            return Theme.Colors.success
        }
        if progress >= 1 { return Theme.Colors.success }
        if progress > 0.5 { return Theme.Colors.accent }
        return Theme.Colors.textMuted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                RingGaugeView(
                    value: goal.currentAmount,
                    maxValue: goal.targetAmount,
                    size: 64,
                    strokeWidth: 6,
                    color: color
                ) {
                    GoalTreeView(progress: progress, goalType: goal.goalType, size: 24)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(goal.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.text)
                        if goal.isSavingsTarget == true {
                            Text("Saving")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Theme.Colors.flowFlex)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.flowFlex.opacity(0.08))
                                .cornerRadius(Theme.Radii.badge)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radii.badge)
                                        .stroke(Theme.Colors.flowFlex.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                        if goal.isPayoff == true {
                            Text("Payoff")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Theme.Colors.flowPayoff)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.flowPayoff.opacity(0.12))
                                .cornerRadius(Theme.Radii.badge)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radii.badge)
                                        .stroke(Theme.Colors.flowPayoff.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                    }

                    Text(goalTypeLabel)
                        .font(Theme.Fonts.micro)
                        .foregroundColor(Theme.Colors.textMuted)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.isPayoff == true ? "Paid" : "Current")
                                .font(Theme.Fonts.nano)
                                .foregroundColor(Theme.Colors.textMuted)
                            Text(Formatters.currency(goal.currentAmount, decimals: false))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.text)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.isPayoff == true ? "Total" : "Target")
                                .font(Theme.Fonts.nano)
                                .foregroundColor(Theme.Colors.textMuted)
                            Text(Formatters.currency(goal.targetAmount, decimals: false))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.text)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.leading, 8)

                Spacer()
            }

            HStack(spacing: 8) {
                Button(action: { showingDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.error)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                }
                .disabled(deleting)
            }
        }
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture { showingEditSheet = true }
        .sheet(isPresented: $showingEditSheet) {
            EditGoalSheet(goal: goal, onSave: onUpdate)
        }
        .alert("Delete Goal", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteGoal() }
        } message: {
            Text("Are you sure you want to delete \"\(goal.name)\"? This cannot be undone.")
        }
    }

    func deleteGoal() {
        deleting = true
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/goals?id=\(goal.id)",
                    method: "DELETE"
                )
                onUpdate()
                onSuccess?("Goal deleted")
            } catch {
                onError?("Failed to delete goal")
            }
            deleting = false
        }
    }

    var goalTypeLabel: String {
        switch goal.goalType {
        case "monthly_savings": return "Monthly Savings"
        case "category_limit": return "Category Limit"
        case "fund_target": return "Fund Target"
        case "net_worth": return "Net Worth"
        default: return goal.goalType
        }
    }
}

struct AddGoalSheet: View {
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var goalType = "monthly_savings"
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var saving = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Goal Name", text: $name)
                    Picker("Type", selection: $goalType) {
                        Text("Monthly Savings").tag("monthly_savings")
                        Text("Fund Target").tag("fund_target")
                        Text("Category Limit").tag("category_limit")
                        Text("Net Worth").tag("net_worth")
                    }
                }

                Section {
                    TextField("Target Amount", text: $targetAmount)
                        .keyboardType(.decimalPad)
                    TextField("Current Amount", text: $currentAmount)
                        .keyboardType(.decimalPad)
                }

                if !error.isEmpty {
                    Section {
                        Text(error)
                            .font(Theme.Fonts.small)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveGoal() }
                        .disabled(saving || name.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }

    func saveGoal() {
        error = ""
        guard let target = Double(targetAmount) else {
            error = "Invalid target amount"
            return
        }
        let current = Double(currentAmount) ?? 0
        guard target > 0 else {
            error = "Target must be greater than zero"
            return
        }
        guard current >= 0 else {
            error = "Current amount can't be negative"
            return
        }
        guard current <= target else {
            error = "Current amount can't exceed target"
            return
        }

        saving = true
        Task {
            do {
                struct CreateGoalRequest: Encodable {
                    let name: String
                    let goalType: String
                    let targetAmount: Double
                    let currentAmount: Double
                }

                let _: GoalResponse = try await APIClient.shared.request(
                    "/api/goals",
                    method: "POST",
                    body: CreateGoalRequest(
                        name: name,
                        goalType: goalType,
                        targetAmount: target,
                        currentAmount: current
                    )
                )
                onSave()
                dismiss()
            } catch {
                self.error = "Failed to save goal"
            }
            saving = false
        }
    }
}

struct EditGoalSheet: View {
    let goal: Goal
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var goalType: String
    @State private var targetAmount: String
    @State private var currentAmount: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var saving = false
    @State private var error = ""

    init(goal: Goal, onSave: @escaping () -> Void) {
        self.goal = goal
        self.onSave = onSave
        self._name = State(initialValue: goal.name)
        self._goalType = State(initialValue: goal.goalType)
        self._targetAmount = State(initialValue: String(format: "%.0f", goal.targetAmount))
        self._currentAmount = State(initialValue: String(format: "%.0f", goal.currentAmount))
        if let dl = goal.deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            self._hasDeadline = State(initialValue: true)
            self._deadline = State(initialValue: formatter.date(from: dl) ?? Date())
        } else {
            self._hasDeadline = State(initialValue: false)
            self._deadline = State(initialValue: Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $goalType) {
                        Text("Monthly Savings").tag("monthly_savings")
                        Text("Fund Target").tag("fund_target")
                        Text("Category Limit").tag("category_limit")
                        Text("Net Worth").tag("net_worth")
                    }
                } header: {
                    Text("Goal").sectionHeaderStyle()
                }

                Section {
                    HStack {
                        Text(goal.isPayoff == true ? "Total" : "Target")
                        Spacer()
                        TextField("0", text: $targetAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(goal.isPayoff == true ? "Paid" : "Current")
                        Spacer()
                        TextField("0", text: $currentAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Amounts").sectionHeaderStyle()
                }

                Section {
                    Toggle("Has Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Date", selection: $deadline, displayedComponents: .date)
                    }
                } header: {
                    Text("Deadline").sectionHeaderStyle()
                }

                if !error.isEmpty {
                    Section {
                        Text(error)
                            .font(Theme.Fonts.small)
                            .foregroundColor(Theme.Colors.error)
                    }
                }

                if goal.isPayoff == true {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(Theme.Colors.rose)
                                .font(Theme.Fonts.small)
                            Text("This goal tracks a past expense being paid off over time.")
                                .font(Theme.Fonts.small)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveGoal() }
                        .disabled(saving || name.isEmpty || targetAmount.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    func saveGoal() {
        error = ""
        guard let target = Double(targetAmount) else {
            error = "Invalid target amount"
            return
        }
        let current = Double(currentAmount) ?? 0
        guard target > 0 else {
            error = "Target must be greater than zero"
            return
        }
        guard current >= 0 else {
            error = "Current amount can't be negative"
            return
        }
        guard current <= target else {
            error = "Current amount can't exceed target"
            return
        }
        if hasDeadline && deadline < Date() {
            error = "Deadline can't be in the past"
            return
        }

        saving = true
        Task {
            do {
                var body: [String: Any] = [
                    "id": goal.id,
                    "name": name,
                    "goalType": goalType,
                    "targetAmount": target,
                    "currentAmount": current,
                ]
                if hasDeadline {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    body["deadline"] = formatter.string(from: deadline)
                } else {
                    body["deadline"] = NSNull()
                }

                let _: GoalResponse = try await APIClient.shared.request(
                    "/api/goals",
                    method: "PATCH",
                    body: body
                )
                onSave()
                dismiss()
            } catch {
                self.error = "Failed to update goal"
            }
            saving = false
        }
    }
}

import SwiftUI

struct SavingsGoalSheet: View {
    let month: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var allGoals: [Goal] = []
    @State private var loading = true
    @State private var saving = false

    // Inline editing
    @State private var editingGoalId: Int? = nil
    @State private var contributionText = ""

    // New goal creation
    @State private var showingNewGoal = false
    @State private var newGoalName = ""
    @State private var newGoalAmount = ""
    @State private var newGoalContribution = ""

    private var totalSaving: Double {
        allGoals.reduce(0) { $0 + ($1.monthlyContribution ?? 0) }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary bar
                        if totalSaving > 0 {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.flowFlex)
                                Text("Saving \(Formatters.currency(totalSaving, decimals: false))/mo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.Colors.flowFlex)
                                Spacer()
                                Text("from flex budget")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                            .padding(12)
                            .background(Theme.Colors.flowFlex.opacity(0.06))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.Colors.flowFlex.opacity(0.3), lineWidth: 1)
                            )
                        }

                        // Goal list
                        if allGoals.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "target")
                                    .font(.system(size: 28))
                                    .foregroundColor(Theme.Colors.textDisabled)
                                Text("No goals yet")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(allGoals) { goal in
                                goalCard(goal)
                            }
                        }

                        // Create new goal
                        if showingNewGoal {
                            newGoalForm
                        } else {
                            Button {
                                showingNewGoal = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Theme.Colors.accent)
                                    Text("Create New Goal")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.Colors.accent)
                                    Spacer()
                                }
                                .padding(12)
                                .cardStyle()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Savings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadGoals() }
    }

    // MARK: - Goal Card

    private func goalCard(_ goal: Goal) -> some View {
        let progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0
        let mc = goal.monthlyContribution ?? 0
        let isEditing = editingGoalId == goal.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.border, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min(progress, 1))
                        .stroke(Theme.Colors.flowFlex, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.text)
                    Text("\(Formatters.currency(goal.currentAmount, decimals: false)) of \(Formatters.currency(goal.targetAmount, decimals: false))")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(progress >= 1 ? Theme.Colors.success : Theme.Colors.textSecondary)
            }

            // Contribution row
            Divider()
            HStack(spacing: 8) {
                if isEditing {
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("0", text: $contributionText)
                            .font(.system(size: 14, weight: .medium))
                            .keyboardType(.numberPad)
                            .foregroundColor(Theme.Colors.text)
                            .frame(width: 60)
                        Text("/mo")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.Colors.flowFlex, lineWidth: 1)
                    )

                    Spacer()

                    Button("Save") {
                        saveContribution(goal)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.accent)
                    .cornerRadius(6)
                    .disabled(saving)
                } else {
                    if mc > 0 {
                        Text("\(Formatters.currency(mc, decimals: false))/mo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.flowFlex)

                        Spacer()

                        Button("Edit") {
                            editingGoalId = goal.id
                            contributionText = String(format: "%.0f", mc)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)

                        Button("Pause") {
                            contributionText = "0"
                            editingGoalId = goal.id
                            saveContribution(goal)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.error)
                    } else {
                        Text("Not saving")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textMuted)

                        Spacer()

                        // Auto-pace button if deadline exists
                        if let deadline = goal.deadline {
                            let autoPace = computeAutoPace(goal: goal, deadline: deadline)
                            if autoPace > 0 {
                                Button("Auto-pace \(Formatters.currency(autoPace, decimals: false))/mo") {
                                    contributionText = String(format: "%.0f", autoPace)
                                    editingGoalId = goal.id
                                    saveContribution(goal)
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.flowFlex)
                            }
                        }

                        Button("Set $/mo") {
                            editingGoalId = goal.id
                            contributionText = ""
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
        }
        .padding(12)
        .background(mc > 0 ? Theme.Colors.flowFlex.opacity(0.04) : Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(mc > 0 ? Theme.Colors.flowFlex.opacity(0.3) : Theme.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - New Goal Form

    private var newGoalForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Goal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Colors.text)

            TextField("Goal name", text: $newGoalName)
                .font(.system(size: 14))
                .padding(10)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                    HStack(spacing: 2) {
                        Text("$")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("0", text: $newGoalAmount)
                            .font(.system(size: 14))
                            .keyboardType(.numberPad)
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Save/mo")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                    HStack(spacing: 2) {
                        Text("$")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("0", text: $newGoalContribution)
                            .font(.system(size: 14))
                            .keyboardType(.numberPad)
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))
                }
            }

            HStack(spacing: 8) {
                Button("Cancel") {
                    showingNewGoal = false
                    newGoalName = ""
                    newGoalAmount = ""
                    newGoalContribution = ""
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                Button(saving ? "Creating..." : "Create") {
                    createGoal()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(validNewGoal ? Theme.Colors.accent : Theme.Colors.textDisabled)
                .cornerRadius(6)
                .disabled(!validNewGoal || saving)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.border, lineWidth: 1))
    }

    private var validNewGoal: Bool {
        guard let amount = Double(newGoalAmount), amount > 0, !newGoalName.isEmpty else { return false }
        return true
    }

    // MARK: - API

    private func loadGoals() {
        Task {
            do {
                let response: GoalsResponse = try await APIClient.shared.request("/api/goals")
                allGoals = response.goals.filter { $0.goalType == "fund_target" || $0.goalType == "net_worth" }
            } catch {
                print("Load goals error:", error)
            }
            loading = false
        }
    }

    private func saveContribution(_ goal: Goal) {
        let amount = Double(contributionText) ?? 0
        saving = true
        Task {
            do {
                let _: GoalResponse = try await APIClient.shared.request(
                    "/api/goals",
                    method: "PATCH",
                    body: [
                        "id": goal.id,
                        "monthlyContribution": amount,
                    ] as [String: Any]
                )
                editingGoalId = nil
                onSave()
                loadGoals()
            } catch {
                print("Save contribution error:", error)
            }
            saving = false
        }
    }

    private func createGoal() {
        guard let target = Double(newGoalAmount), !newGoalName.isEmpty else { return }
        let contribution = Double(newGoalContribution) ?? 0
        saving = true
        Task {
            do {
                let _: GoalResponse = try await APIClient.shared.request(
                    "/api/goals",
                    method: "POST",
                    body: [
                        "name": newGoalName,
                        "goalType": "fund_target",
                        "targetAmount": target,
                        "monthlyContribution": contribution,
                    ] as [String: Any]
                )
                showingNewGoal = false
                newGoalName = ""
                newGoalAmount = ""
                newGoalContribution = ""
                onSave()
                loadGoals()
            } catch {
                print("Create goal error:", error)
            }
            saving = false
        }
    }

    // MARK: - Helpers

    private func computeAutoPace(goal: Goal, deadline: String) -> Double {
        let remaining = goal.targetAmount - goal.currentAmount
        guard remaining > 0 else { return 0 }
        let parts = deadline.split(separator: "-")
        guard parts.count >= 2, let dY = Int(parts[0]), let dM = Int(parts[1]) else { return remaining }
        let mParts = month.split(separator: "-")
        guard mParts.count == 2, let cY = Int(mParts[0]), let cM = Int(mParts[1]) else { return remaining }
        let months = max((dY - cY) * 12 + (dM - cM), 1)
        return ceil(remaining / Double(months))
    }
}

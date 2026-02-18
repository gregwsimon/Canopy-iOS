import SwiftUI

struct GoalsCardView: View {
    let goals: [Goal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GOALS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            if goals.isEmpty {
                VStack(spacing: 6) {
                    GoalTreeView(progress: 0, size: 28)
                    Text("Plant your first goal")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(goals.prefix(3)) { goal in
                        GoalRowView(goal: goal)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct GoalRowView: View {
    let goal: Goal

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
        HStack(spacing: 12) {
            GoalTreeView(progress: progress, goalType: goal.goalType, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                    .lineLimit(1)

                Text("\(formatCompact(goal.currentAmount)) / \(formatCompact(goal.targetAmount))")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            let k = value / 1000
            if k >= 10 {
                return "$\(Int(k))k"
            }
            return String(format: "$%.1fk", k)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

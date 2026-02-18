import SwiftUI

struct AllocationAmountSheet: View {
    let credit: CreditItem
    let action: String
    let targetTransaction: SearchTransaction?
    let targetCategory: Category?
    let targetGoal: GoalOption?
    let onAllocate: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var initialized = false

    private var creditRemaining: Double {
        credit.remainingAmount ?? credit.amount
    }

    private var targetRemaining: Double? {
        guard let tx = targetTransaction else { return nil }
        return tx.remainingAmount
    }

    private var maxAmount: Double {
        if let tr = targetRemaining {
            return min(creditRemaining, tr)
        }
        return creditRemaining
    }

    private var enteredAmount: Double {
        Double(amountText) ?? 0
    }

    private var isValid: Bool {
        enteredAmount > 0 && enteredAmount <= maxAmount + 0.01
    }

    private var actionLabel: String {
        switch action {
        case "return": return "Match Return"
        case "healthcare": return "Match Reimbursement"
        case "spend_offset": return "Apply Offset"
        case "goal": return "Add to Goal"
        case "other_income": return "Classify as Income"
        case "tax_refund": return "Classify as Tax Refund"
        default: return "Allocate"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Credit info
                VStack(spacing: 4) {
                    Text("Credit")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textMuted)
                        .tracking(0.5)
                    Text(credit.description ?? "Credit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.text)
                    Text("+\(Formatters.currency(credit.amount))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.success)
                    if creditRemaining < credit.amount {
                        Text("Remaining: \(Formatters.currency(creditRemaining))")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.warning)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Colors.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card).stroke(Theme.Colors.border, lineWidth: 1))
                .padding(.horizontal)

                // Target info (for return/healthcare)
                if let tx = targetTransaction {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textMuted)

                        Text(action == "healthcare" ? "Healthcare Expense" : "Original Purchase")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)
                            .tracking(0.5)
                        Text(tx.description ?? "Transaction")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.text)
                        Text(Formatters.currency(abs(tx.amount ?? 0)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.error)
                        if let remaining = tx.remainingAmount, remaining < abs(tx.amount ?? 0) {
                            Text("Unmatched: \(Formatters.currency(remaining))")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.warning)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card).stroke(Theme.Colors.border, lineWidth: 1))
                    .padding(.horizontal)
                }

                // Target info (for category/goal)
                if let cat = targetCategory {
                    targetPill(label: "Category Offset", value: cat.name)
                }
                if let goal = targetGoal {
                    targetPill(label: "Goal", value: "\(goal.name) (\(Formatters.currency(goal.remaining)) left)")
                }

                // Amount input
                VStack(spacing: 8) {
                    Text("Amount to allocate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)

                    HStack {
                        Text("$")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.text)
                        TextField("0", text: $amountText)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 200)
                    .padding(.vertical, 8)

                    if !isValid && enteredAmount > 0 {
                        Text("Max: \(Formatters.currency(maxAmount))")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Allocate button
                Button {
                    onAllocate(enteredAmount)
                    dismiss()
                } label: {
                    Text(actionLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValid ? Theme.Colors.text : Theme.Colors.textDisabled)
                        .cornerRadius(10)
                }
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
            .background(Theme.Colors.background)
            .navigationTitle("Allocate Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .onAppear {
                if !initialized {
                    amountText = formatAmount(maxAmount)
                    initialized = true
                }
            }
        }
    }

    // MARK: - Components

    private func targetPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.down")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textMuted)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card).stroke(Theme.Colors.border, lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: - Formatters

    private func formatAmount(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

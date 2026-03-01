import SwiftUI

struct CarryIntentionSheet: View {
    let carry: CarryData
    let options: CarryOptions
    var onChanged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAction: String? = nil
    @State private var selectedGoalId: Int? = nil
    @State private var selectedSpreadId: Int? = nil
    @State private var customAmount: String = ""
    @State private var spreadMonths: Int = 1
    @State private var saving = false

    private var monthLabel: String {
        Formatters.monthLabel(carry.sourceMonth)
    }

    private var total: Double { abs(carry.surplusDeficit) }

    private var surplusActions: [(id: String, label: String, icon: String)] {
        [
            ("bank_it", "Break Even", "equal.circle"),
            ("goal_contribution", "Save to Goal", "target"),
            ("spread_paydown", "Pay Down Payoff", "arrow.down.circle"),
            ("next_month_boost", "Boost Flex", "plus.circle"),
        ]
    }

    private var deficitActions: [(id: String, label: String, icon: String)] {
        [
            ("absorb_deficit", "Break Even", "equal.circle"),
            ("goal_reduction", "Remove Savings", "minus.circle"),
            ("next_month_reduce_multi", "Payoff Over Time", "clock"),
            ("next_month_reduce", "Decrease Flex", "arrow.down.circle"),
        ]
    }

    private var actions: [(id: String, label: String, icon: String)] {
        carry.isSurplus ? surplusActions : deficitActions
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Source banner
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(monthLabel) had a")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("\(Formatters.currency(total, decimals: false)) \(carry.isSurplus ? "surplus" : "deficit")")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(carry.isSurplus ? Theme.Colors.success : Theme.Colors.error)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(carry.isSurplus ? Theme.Colors.successBg : Theme.Colors.errorBg)
                    .cornerRadius(12)

                    // Current intention
                    if !carry.allocations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Intention")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Colors.textMuted)

                            ForEach(carry.allocations) { alloc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friendlyLabel(alloc))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Theme.Colors.text)
                                        if let detail = friendlyDetail(alloc) {
                                            Text(detail)
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Text(Formatters.currency(alloc.amount, decimals: false))
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(Theme.Colors.text)
                                }
                                .padding(12)
                                .background(Theme.Colors.surfaceSolid)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.Colors.border, lineWidth: 1)
                                )
                            }
                        }
                    }

                    // Action buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text(carry.allocations.isEmpty ? "Set Intention" : "Change Intention")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ], spacing: 8) {
                            ForEach(actions, id: \.id) { action in
                                ActionBox(
                                    label: action.label,
                                    icon: action.icon,
                                    isActive: selectedAction == action.id,
                                    onTap: { selectedAction = selectedAction == action.id ? nil : action.id }
                                )
                            }
                        }
                    }

                    // Inline picker
                    if let action = selectedAction {
                        pickerView(for: action)
                    }
                }
                .padding(16)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Carry Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14))
                }
            }
        }
    }

    // MARK: - Picker Views

    @ViewBuilder
    private func pickerView(for action: String) -> some View {
        switch action {
        case "goal_contribution", "goal_reduction":
            goalPicker(action: action)
        case "spread_paydown":
            spreadPicker()
        case "next_month_boost", "next_month_reduce":
            amountConfirm(action: action)
        case "next_month_reduce_multi":
            durationPicker()
        case "bank_it", "absorb_deficit":
            simpleConfirm(action: action)
        default:
            EmptyView()
        }
    }

    private func goalPicker(action: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Goal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)

            ForEach(options.goals) { goal in
                Button {
                    selectedGoalId = goal.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.text)
                            Text("\(Formatters.currency(goal.currentAmount, decimals: false)) / \(Formatters.currency(goal.targetAmount, decimals: false))")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        if selectedGoalId == goal.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.success)
                        }
                    }
                    .padding(12)
                    .background(selectedGoalId == goal.id ? Theme.Colors.successBg : Theme.Colors.surfaceSolid)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedGoalId == goal.id ? Theme.Colors.success.opacity(0.3) : Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if selectedGoalId != nil {
                amountInput()
                applyButton(action: action)
            }
        }
    }

    private func spreadPicker() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Payoff")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)

            ForEach(options.spreads) { spread in
                Button {
                    selectedSpreadId = spread.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spread.description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.text)
                            Text("\(Formatters.currency(spread.monthlyPortion, decimals: false))/mo · \(spread.monthsRemaining) left")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        if selectedSpreadId == spread.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.success)
                        }
                    }
                    .padding(12)
                    .background(selectedSpreadId == spread.id ? Theme.Colors.successBg : Theme.Colors.surfaceSolid)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedSpreadId == spread.id ? Theme.Colors.success.opacity(0.3) : Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            if selectedSpreadId != nil {
                amountInput()
                applyButton(action: "spread_paydown")
            }
        }
    }

    private func durationPicker() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payoff Duration")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: 8) {
                ForEach([2, 3, 6], id: \.self) { months in
                    Button {
                        spreadMonths = months
                    } label: {
                        Text("\(months) mo")
                            .font(.system(size: 13, weight: spreadMonths == months ? .semibold : .regular))
                            .foregroundColor(spreadMonths == months ? .white : Theme.Colors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(spreadMonths == months ? Theme.Colors.teal : Theme.Colors.surfaceSolid)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(spreadMonths == months ? Color.clear : Theme.Colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("\(Formatters.currency(total / Double(spreadMonths), decimals: false))/mo for \(spreadMonths) months")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)

            applyButton(action: "next_month_reduce")
        }
    }

    private func amountConfirm(action: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            amountInput()
            applyButton(action: action)
        }
    }

    private func simpleConfirm(action: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apply \(Formatters.currency(total, decimals: false)) as break even")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
            applyButton(action: action)
        }
    }

    private func amountInput() -> some View {
        HStack {
            Text("Amount")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            TextField(Formatters.currency(total, decimals: false), text: $customAmount)
                .font(.system(size: 13, design: .monospaced))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .padding(8)
                .background(Theme.Colors.surfaceSolid)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))
        }
    }

    private func applyButton(action: String) -> some View {
        Button {
            Task { await allocate(action: action) }
        } label: {
            HStack {
                if saving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Apply")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.Colors.teal)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(saving)
    }

    // MARK: - Allocation API

    private func allocate(action: String) async {
        saving = true
        defer { saving = false }

        let amount = Double(customAmount) ?? total
        let effectiveAction = action == "next_month_reduce_multi" ? "next_month_reduce" : action

        var body: [String: Any] = [
            "recap_id": carry.recapId,
            "allocation_type": effectiveAction,
            "amount": min(amount, total),
            "reset_existing": !carry.allocations.isEmpty,
        ]

        if action == "goal_contribution" || action == "goal_reduction", let gid = selectedGoalId {
            body["target_goal_id"] = gid
        }
        if action == "spread_paydown", let sid = selectedSpreadId {
            body["target_transaction_id"] = sid
        }
        if action == "next_month_reduce_multi" || (action == "next_month_reduce" && spreadMonths > 1) {
            body["amortize_months"] = spreadMonths
        }

        do {
            let _: AllocateResponse = try await APIClient.shared.request(
                "/api/recap/allocate",
                method: "POST",
                body: body
            )
            onChanged?()
            dismiss()
        } catch {
            print("Carry allocate error:", error)
        }
    }

    // MARK: - Helpers

    private func friendlyLabel(_ alloc: CarryAllocation) -> String {
        switch alloc.type {
        case "bank_it": return "Break even"
        case "absorb_deficit": return "Break even"
        case "goal_contribution": return "Save to \(alloc.targetGoalName ?? "goal")"
        case "goal_reduction": return "Remove from \(alloc.targetGoalName ?? "goal")"
        case "spread_paydown": return "Pay down \(alloc.targetSpreadDescription ?? "payoff")"
        case "next_month_boost": return "Increase flexible spend"
        case "next_month_reduce":
            if let months = alloc.amortizeMonths, months > 1 {
                return "Payoff over \(months) months"
            }
            return "Decrease flexible spend"
        default: return alloc.type
        }
    }

    private func friendlyDetail(_ alloc: CarryAllocation) -> String? {
        switch alloc.type {
        case "goal_contribution", "goal_reduction":
            return alloc.targetGoalName
        case "spread_paydown":
            return alloc.targetSpreadDescription
        default:
            return nil
        }
    }
}

// MARK: - Action Box

private struct ActionBox: View {
    let label: String
    let icon: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .foregroundColor(isActive ? Theme.Colors.teal : Theme.Colors.textSecondary)
            .background(isActive ? Theme.Colors.teal.opacity(0.06) : Theme.Colors.surfaceSolid)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Theme.Colors.teal : Theme.Colors.border, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

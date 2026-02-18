import SwiftUI

struct AmortizeSuggestion {
    let amount: Double
    let description: String
}

struct PulseCardView: View {
    let flexibleRemaining: Double
    let flexibleBudget: Double
    let daysRemaining: Int
    let dailyBudget: Double
    var savingsTarget: Double = 0
    var onGoalTap: (() -> Void)? = nil
    var amortizeSuggestion: AmortizeSuggestion? = nil
    var onAmortizeTap: (() -> Void)? = nil
    var onAmortizeDismiss: (() -> Void)? = nil

    private var spentRatio: Double {
        guard flexibleBudget > 0 else { return 1 }
        return max(flexibleBudget - flexibleRemaining, 0) / flexibleBudget
    }

    private var isOverBudget: Bool {
        flexibleRemaining < 0
    }

    private var remainingPercent: Int {
        guard flexibleBudget > 0 else { return 0 }
        if isOverBudget {
            return Int(flexibleRemaining / flexibleBudget * 100) // negative
        }
        return Int((1.0 - spentRatio) * 100)
    }

    private var thresholdColor: Color {
        if flexibleRemaining < 0 { return Theme.Colors.error }
        let remainingRatio = 1.0 - spentRatio
        if remainingRatio > 2.0 / 3.0 { return Theme.Colors.success }
        if remainingRatio > 1.0 / 3.0 { return Theme.Colors.warning }
        return Theme.Colors.error
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("FLEXIBLE REMAINING")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .tracking(1)

                        Button {
                            onGoalTap?()
                        } label: {
                            Image(systemName: savingsTarget > 0 ? "plus.circle.fill" : "plus.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(savingsTarget > 0 ? Theme.Colors.teal : Theme.Colors.textMuted)
                        }
                    }

                    Text(Formatters.currency(abs(flexibleRemaining), decimals: false))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(thresholdColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Formatters.currency(dailyBudget, decimals: false))/day \u{2022} \(daysRemaining) days left")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)

                        if savingsTarget > 0 {
                            Text("Saving \(Formatters.currency(savingsTarget, decimals: false))/mo")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.Colors.teal)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                if isOverBudget {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.error)
                        Text("\(remainingPercent)%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 80, height: 80)
                } else {
                    RingGaugeView(
                        value: max(flexibleRemaining, 0),
                        maxValue: flexibleBudget,
                        size: 80,
                        strokeWidth: 9,
                        color: thresholdColor,
                        clockwise: true
                    ) {
                        Text("\(remainingPercent)%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(thresholdColor)
                    }
                }
            }
            .padding(20)

            if let suggestion = amortizeSuggestion {
                Button {
                    onAmortizeTap?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#92400e"))
                        Text("\(Formatters.currency(abs(suggestion.amount), decimals: false)) \(suggestion.description) — Spread?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#92400e"))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            onAmortizeDismiss?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(hex: "#b45309"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.warningBg)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "#fde68a"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radii.card)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

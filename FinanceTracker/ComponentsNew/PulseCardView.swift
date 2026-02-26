import SwiftUI

struct AmortizeSuggestion {
    let amount: Double
    let description: String
}

struct PulseCardView: View {
    let flexibleRemaining: Double
    let flexibleBudget: Double
    let daysRemaining: Int
    let daysInMonth: Int
    let dailyBudget: Double
    var historicalPace: Double? = nil
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

    @State private var animatedProgress: Double = 0

    private var targetProgress: Double {
        guard flexibleBudget > 0 else { return 0 }
        if isOverBudget { return 1.0 }
        return min(max(1.0 - spentRatio, 0), 1)
    }

    private var spent: Double {
        max(flexibleBudget - flexibleRemaining, 0)
    }

    /// Pace deviation vs historical personal spending curve.
    /// Negative = below your usual pace (good), positive = above (bad).
    /// Returns nil if no historical data available.
    private var paceDeviation: Int? {
        guard let expectedPace = historicalPace, expectedPace > 0, flexibleBudget > 0 else { return nil }
        let actualPace = spent / flexibleBudget
        let deviation = actualPace - expectedPace
        return Int(round(deviation * 100))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Flexible remaining")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(.bottom, 8)

                // Hero number
                Text(isOverBudget
                    ? "−\(Formatters.currency(abs(flexibleRemaining), decimals: false))"
                    : Formatters.currency(flexibleRemaining, decimals: false))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(thresholdColor)
                    .padding(.bottom, 14)

                // Capsule progress bar
                CapsuleProgressBar(
                    progress: animatedProgress,
                    spentLabel: "\(Formatters.currency(spent, decimals: false)) spent",
                    totalLabel: Formatters.currency(flexibleBudget, decimals: false),
                    color: thresholdColor,
                    isOverBudget: isOverBudget
                )
                .padding(.bottom, 14)

                // Footer: $X/day · X days left · ↗ X% pace
                HStack(spacing: 0) {
                    if isOverBudget {
                        Text("\(Formatters.currency(abs(flexibleRemaining), decimals: false)) over budget")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSecondary)
                    } else {
                        Text("\(Formatters.currency(dailyBudget, decimals: false))/day")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(" · ")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#cccccc"))
                        Text("\(daysRemaining) \(daysRemaining == 1 ? "day" : "days") left")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(" · ")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#cccccc"))

                        let daysElapsed = max(daysInMonth - daysRemaining, 1)
                        let expectedPct = Double(daysElapsed) / Double(daysInMonth)
                        let actualPct = flexibleBudget > 0 ? spent / flexibleBudget : 0
                        let paceRaw = expectedPct > 0 ? Int(round(((actualPct / expectedPct) - 1) * 100)) : 0
                        let paceAbs = abs(paceRaw)
                        let paceColor = paceRaw > 5 ? thresholdColor : (paceRaw < -5 ? Theme.Colors.success : Theme.Colors.textMuted)

                        HStack(spacing: 2) {
                            Image(systemName: paceRaw > 0 ? "arrow.up.right" : (paceRaw < 0 ? "arrow.down.right" : "arrow.right"))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(paceColor)
                            Text("\(paceAbs)% \(paceRaw > 0 ? "pace" : (paceRaw < 0 ? "under" : "on pace"))")
                                .font(.system(size: 11))
                                .foregroundColor(paceColor)
                        }
                    }
                    Spacer()
                }
            }
            .padding(20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = targetProgress
                }
            }
            .onChange(of: targetProgress) { oldValue, newValue in
                withAnimation(.easeOut(duration: 0.5)) {
                    animatedProgress = newValue
                }
            }

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
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Capsule Progress Bar

private struct CapsuleProgressBar: View {
    let progress: Double
    let spentLabel: String
    let totalLabel: String
    let color: Color
    var isOverBudget: Bool = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = isOverBudget ? width : width * min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.black.opacity(0.04))

                // Fill
                Capsule()
                    .fill(color.opacity(isOverBudget ? 0.2 : 0.18))
                    .frame(width: fillWidth)

                // Labels
                HStack {
                    if isOverBudget {
                        Spacer()
                        Text("over budget")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(color)
                        Spacer()
                    } else {
                        Text(spentLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(color)
                            .padding(.leading, 14)

                        Spacer()

                        Text(totalLabel)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#aaaaaa"))
                            .padding(.trailing, 14)
                    }
                }
            }
        }
        .frame(height: 28)
        .clipShape(Capsule())
    }
}

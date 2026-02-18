import SwiftUI

struct NetCashCardView: View {
    let metrics: NetCashMetrics

    private var totalPending: Double {
        metrics.pendingHealthcare + metrics.pendingReturns
    }

    private var goalEarmarked: Double {
        metrics.goalEarmarked ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NET CASH")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            // Net cash total with breakdown pills to the right
            HStack(alignment: .center) {
                Text(Formatters.currency(metrics.net, decimals: false))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(metrics.net >= 0 ? Theme.Colors.success : Theme.Colors.error)

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    MetricPill(label: "Checking", value: metrics.checking, color: Theme.Colors.success)
                    MetricPill(label: "CC Debt", value: -metrics.creditDebt, color: Theme.Colors.error)
                }
            }

            // Adjusted net cash annotation (only when pending > 0)
            if totalPending > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.success)

                    Text(Formatters.currency(metrics.net + totalPending, decimals: false))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.success)

                    Text("after refunds")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)

                    Spacer()

                    Text("+\(Formatters.currency(totalPending, decimals: false))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.Colors.success)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.Colors.success.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.Colors.success.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(6)
            }

            // After goals — shows free cash after earmarked savings are flushed
            if goalEarmarked > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.teal)

                    Text(Formatters.currency(metrics.net - goalEarmarked, decimals: false))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.teal)

                    Text("after goals")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)

                    Spacer()

                    Text("−\(Formatters.currency(goalEarmarked, decimals: false))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.Colors.teal)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.Colors.teal.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.Colors.teal.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(6)
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#f8faf9"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#e8ece9"), lineWidth: 1)
        )
    }
}

// MARK: - Metric Pill

private struct MetricPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textSecondary)
            Text(Formatters.currency(value, decimals: false))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.text)
        }
    }
}

// MARK: - Compact Callout

private struct CompactCallout: View {
    let icon: String
    let iconColor: Color
    let title: String
    let amount: Double
    let bgColor: Color
    let borderColor: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.text)
            if amount > 0 {
                Text(Formatters.currency(amount, decimals: false))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(iconColor)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textDisabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(bgColor)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

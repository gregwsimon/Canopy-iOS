import SwiftUI

struct NetCashCardView: View {
    let metrics: NetCashMetrics
    var onPendingRefundsTap: (() -> Void)?
    var onGoalsTap: (() -> Void)?

    private var totalPending: Double {
        metrics.pendingHealthcare + metrics.pendingReturns
    }

    private var goalEarmarked: Double {
        metrics.goalEarmarked ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("Net cash")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)

            // Hero row: big number + breakdown
            HStack(alignment: .center) {
                Text(Formatters.currency(metrics.net, decimals: false))
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(metrics.net >= 0 ? Theme.Colors.text : Theme.Colors.error)

                Spacer()

                // Checking / CC Debt — aligned, colored numbers, no dots
                VStack(spacing: 0) {
                    HStack {
                        Text("Checking")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.currency(metrics.checking, decimals: false))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.success)
                    }
                    .padding(.vertical, 6)

                    Divider()

                    HStack {
                        Text("CC Debt")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.currency(metrics.creditDebt, decimals: false))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.error)
                    }
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .frame(width: 160)
            }

            // Bottom pills: single-line, full width
            if totalPending > 0 || goalEarmarked > 0 {
                Spacer().frame(height: 4)
                HStack(spacing: 6) {
                    if totalPending > 0 {
                        Button { onPendingRefundsTap?() } label: {
                            HStack(spacing: 4) {
                                Text("Pending refunds")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .lineLimit(1)
                                Text("+\(Formatters.currency(totalPending, decimals: false))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Colors.success)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 6, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textDisabled)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.background)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    if goalEarmarked > 0 {
                        Button { onGoalsTap?() } label: {
                            HStack(spacing: 4) {
                                Text("Earmarked goals")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .lineLimit(1)
                                Text("−\(Formatters.currency(goalEarmarked, decimals: false))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Colors.text)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 6, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textDisabled)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.background)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radii.card)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

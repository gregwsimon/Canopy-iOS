import SwiftUI

struct HealthcareCardView: View {
    let totalPaid: Double
    let pendingReimbursement: Double
    let totalReimbursed: Double
    let netCost: Double

    private var total: Double {
        max(totalPaid, 1)
    }

    private var reimbursedPct: Double {
        totalReimbursed / total
    }

    private var pendingPct: Double {
        pendingReimbursement / total
    }

    private var netPct: Double {
        1 - reimbursedPct - pendingPct
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Healthcare YTD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)

            if totalPaid == 0 {
                Text("No healthcare expenses")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(spacing: 16) {
                    // Donut chart
                    DonutChartView(
                        segments: [
                            (reimbursedPct, Theme.Colors.success),
                            (pendingPct, Theme.Colors.warning),
                            (netPct, Color(hex: "#e5e5e5"))
                        ]
                    )
                    .frame(width: 70, height: 70)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        LegendRow(color: Theme.Colors.success, label: "Reimbursed", amount: totalReimbursed)
                        LegendRow(color: Theme.Colors.warning, label: "Pending", amount: pendingReimbursement)
                        LegendRow(color: Color(hex: "#e5e5e5"), label: "Net Cost", amount: netCost)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct DonutChartView: View {
    let segments: [(Double, Color)]
    var strokeWidth: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - strokeWidth / 2
            var startAngle: Double = -90

            for (percentage, color) in segments {
                if percentage > 0 {
                    let endAngle = startAngle + (percentage * 360)

                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )

                    context.stroke(
                        path,
                        with: .color(color),
                        lineWidth: strokeWidth
                    )

                    startAngle = endAngle
                }
            }
        }
    }
}

struct LegendRow: View {
    let color: Color
    let label: String
    let amount: Double

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            Text(Formatters.currency(amount, decimals: false))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.text)
        }
    }
}

import SwiftUI

struct IncomeBreakdownSheet: View {
    let grossIncome: Double
    let netIncome: Double
    let incomeBreakdown: IncomeBreakdown?

    private var totalDeductions: Double {
        grossIncome - netIncome
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Gross Income header
                HStack {
                    Text("Gross Income")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(Formatters.currency(grossIncome, decimals: false))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.text)
                }
                .padding()
                .cardStyle()

                // Income Sources
                if let breakdown = incomeBreakdown, !breakdown.income.isEmpty {
                    sectionCard(title: "Income Sources", items: breakdown.income, color: Theme.Colors.success)
                }

                // Deductions
                if let breakdown = incomeBreakdown, !breakdown.deductions.isEmpty {
                    sectionCard(title: "Deductions", items: breakdown.deductions, color: Theme.Colors.error, negate: true)
                } else if totalDeductions > 0 {
                    HStack {
                        Text("Deductions")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text("-\(Formatters.currency(totalDeductions, decimals: false))")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.Colors.error)
                    }
                    .padding()
                    .cardStyle()
                }

                // Net Income footer
                HStack {
                    Text("Net Income")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.text)
                    Spacer()
                    Text(Formatters.currency(netIncome, decimals: false))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.Colors.success)
                }
                .padding()
                .background(Theme.Colors.success.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.success.opacity(0.2), lineWidth: 1)
                )
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Income Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionCard(title: String, items: [CategoryTotal], color: Color, negate: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(items) { item in
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: item.color))
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.text)
                    }
                    Spacer()
                    Text("\(negate ? "-" : "")\(Formatters.currency(item.amount, decimals: false))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if item.id != items.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }

            Spacer().frame(height: 12)
        }
        .cardStyle()
    }
}

import SwiftUI

struct PendingRefundsView: View {
    let month: String
    let pendingHealthcare: Double
    let pendingReturns: Double

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Total
                HStack {
                    Text("Total pending")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text("+\(Formatters.currency(pendingHealthcare + pendingReturns, decimals: false))")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.Colors.success)
                }
                .padding(14)
                .background(Theme.Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )

                if pendingHealthcare > 0 {
                    NavigationLink {
                        HealthcareDetailView(month: month)
                    } label: {
                        refundRow(
                            title: "Healthcare",
                            subtitle: "Awaiting reimbursement",
                            amount: pendingHealthcare,
                            color: Theme.Colors.flowCredits
                        )
                    }
                    .buttonStyle(.plain)
                }

                if pendingReturns > 0 {
                    NavigationLink {
                        RefundsView(month: month)
                    } label: {
                        refundRow(
                            title: "Returns",
                            subtitle: "Awaiting refund",
                            amount: pendingReturns,
                            color: Theme.Colors.flowPayoff
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Pending Refunds")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func refundRow(title: String, subtitle: String, amount: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            Text("+\(Formatters.currency(amount, decimals: false))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.Colors.success)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.Colors.textDisabled)
        }
        .padding(14)
        .background(Theme.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

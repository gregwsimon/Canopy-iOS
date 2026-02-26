import SwiftUI

struct ActivityCardView: View {
    let transactions: [RecentTransaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)

            if transactions.isEmpty {
                Text("No recent transactions")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions.prefix(6)) { tx in
                        ActivityRowView(transaction: tx)
                        if tx.id != transactions.prefix(6).last?.id {
                            Divider()
                                .background(Theme.Colors.divider)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct ActivityRowView: View {
    let transaction: RecentTransaction

    var body: some View {
        HStack(spacing: 10) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: transaction.categoryColor))
                .frame(width: 3, height: 32)

            // Transaction details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(transaction.description)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.text)
                        .lineLimit(1)

                    if transaction.isOneTime {
                        TagView(text: "One-time", color: Theme.Colors.textSecondary, bgColor: Theme.Colors.subtleBg)
                    }

                    if transaction.isHealthcare {
                        TagView(text: "Healthcare", color: Color(hex: "#0369a1"), bgColor: Theme.Colors.healthcareBg)
                    }
                }

                Text("\(transaction.categoryName) • \(Formatters.shortDate(transaction.date))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            // Amount
            Text("\(transaction.amount < 0 ? "-" : "+")\(Formatters.currency(abs(transaction.amount), decimals: false))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(transaction.amount < 0 ? Theme.Colors.error : Theme.Colors.success)
        }
        .padding(.vertical, 8)
    }
}

struct TagView: View {
    let text: String
    let color: Color
    let bgColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(bgColor)
            .cornerRadius(2)
    }
}

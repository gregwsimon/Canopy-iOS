import SwiftUI

struct ReturnsCardView: View {
    let pendingAmount: Double
    let receivedAmount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RETURNS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            if pendingAmount == 0 && receivedAmount == 0 {
                Text("No pending returns")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.Colors.warning)
                                .frame(width: 8, height: 8)
                            Text("Pending")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text(Formatters.currency(pendingAmount, decimals: false))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.Colors.text)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.Colors.success)
                                .frame(width: 8, height: 8)
                            Text("Received")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text(Formatters.currency(receivedAmount, decimals: false))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.Colors.text)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

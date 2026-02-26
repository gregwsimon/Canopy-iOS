import SwiftUI

struct WindfallBannerView: View {
    let count: Int
    let total: Double
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.amber.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Text("$")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.amber)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) credit\(count == 1 ? "" : "s") need triage")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.text)
                    Text(Formatters.currency(total, decimals: false) + " total")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textDisabled)
            }
            .padding(14)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Colors.amber.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

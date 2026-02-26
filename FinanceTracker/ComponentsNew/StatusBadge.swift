import SwiftUI

struct StatusBadge: View {
    let text: String
    let textColor: Color
    let bgColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bgColor)
            .cornerRadius(3)
    }

    static func forHealthcare(_ status: String) -> StatusBadge {
        switch status {
        case "pending":
            return StatusBadge(text: "Pending", textColor: Theme.Colors.flowCredits, bgColor: Theme.Colors.flowCredits.opacity(0.12))
        case "complete":
            return StatusBadge(text: "Reimbursed", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
        case "partial":
            return StatusBadge(text: "Partial", textColor: Theme.Colors.flowCredits, bgColor: Theme.Colors.flowCredits.opacity(0.12))
        default:
            return StatusBadge(text: "None", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
        }
    }

    static func forReturn(_ status: String) -> StatusBadge {
        switch status {
        case "pending":
            return StatusBadge(text: "Pending", textColor: Theme.Colors.flowCredits, bgColor: Theme.Colors.flowCredits.opacity(0.12))
        case "received":
            return StatusBadge(text: "Cleared", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
        default:
            return StatusBadge(text: "None", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
        }
    }
}

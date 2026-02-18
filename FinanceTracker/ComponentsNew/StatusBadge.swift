import SwiftUI

struct StatusBadge: View {
    let text: String
    let textColor: Color
    let bgColor: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bgColor)
            .cornerRadius(3)
    }

    static func forHealthcare(_ status: String) -> StatusBadge {
        switch status {
        case "pending":
            return StatusBadge(text: "Pending", textColor: Theme.Colors.warning, bgColor: Theme.Colors.warningBg)
        case "complete":
            return StatusBadge(text: "Reimbursed", textColor: Theme.Colors.success, bgColor: Theme.Colors.successBg)
        case "partial":
            return StatusBadge(text: "Partial", textColor: Theme.Colors.warning, bgColor: Theme.Colors.warningBg)
        default:
            return StatusBadge(text: "None", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
        }
    }

    static func forReturn(_ status: String) -> StatusBadge {
        switch status {
        case "pending":
            return StatusBadge(text: "Pending", textColor: Theme.Colors.warning, bgColor: Theme.Colors.warningBg)
        case "received":
            return StatusBadge(text: "Cleared", textColor: Theme.Colors.success, bgColor: Theme.Colors.successBg)
        default:
            return StatusBadge(text: "None", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
        }
    }
}

import SwiftUI
import UIKit

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 3:
            r = Double((int >> 8) * 17) / 255
            g = Double((int >> 4 & 0xF) * 17) / 255
            b = Double((int & 0xF) * 17) / 255
        case 6:
            r = Double(int >> 16) / 255
            g = Double(int >> 8 & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 3:
            r = CGFloat((int >> 8) * 17) / 255
            g = CGFloat((int >> 4 & 0xF) * 17) / 255
            b = CGFloat((int & 0xF) * 17) / 255
        case 6:
            r = CGFloat(int >> 16) / 255
            g = CGFloat(int >> 8 & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Theme

enum Theme {

    // MARK: Colors

    enum Colors {
        static let background = Color(hex: "#fafafa")
        static let surface = Color.white
        static let text = Color(hex: "#171717")
        static let textSecondary = Color(hex: "#666666")
        static let textMuted = Color(hex: "#999999")
        static let textDisabled = Color(hex: "#cccccc")
        static let border = Color(hex: "#eaeaea")
        static let divider = Color(hex: "#f5f5f5")
        static let subtleBg = Color(hex: "#f0f0f0")

        // Semantic
        static let success = Color(hex: "#0caa41")
        static let error = Color(hex: "#e00000")
        static let warning = Color(hex: "#f5a623")
        static let accent = Color(hex: "#166534")
        static let teal = Color(hex: "#166534")
        static let tealLight = Color(hex: "#15803d")
        static let brandGreen = Color(hex: "#22c55e")
        static let forest = Color(hex: "#1a2e2a")
        static let rose = Color(hex: "#e11d48")
        static let purple = Color(hex: "#8b5cf6")
        static let amber = Color(hex: "#f59e0b")

        // Status backgrounds
        static let successBg = Color(hex: "#dcfce7")
        static let errorBg = Color(hex: "#fef2f2")
        static let warningBg = Color(hex: "#fef3c7")
        static let tealBg = Color(hex: "#f0fdf4")
        static let accentBg = Color(hex: "#f0fdf4")
        static let roseBg = Color(hex: "#fff1f2")
        static let healthcareBg = Color(hex: "#e0f2fe")
    }

    // MARK: Fonts

    enum Fonts {
        static let largeMetric = Font.system(size: 28, weight: .semibold)
        static let title = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 14, weight: .medium)
        static let bodyRegular = Font.system(size: 14)
        static let caption = Font.system(size: 13)
        static let small = Font.system(size: 12)
        static let micro = Font.system(size: 11)
        static let nano = Font.system(size: 10)
        static let sectionHeader = Font.system(size: 10, weight: .medium)
        static let formLabel = Font.system(size: 12, weight: .medium)

        static func currency(_ size: CGFloat = 14, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: Spacing

    enum Spacing {
        static let cardPadding: CGFloat = 16
        static let sectionGap: CGFloat = 16
        static let cardGap: CGFloat = 12
        static let inputPadding: CGFloat = 12
    }

    // MARK: Radii

    enum Radii {
        static let card: CGFloat = 8
        static let button: CGFloat = 8
        static let input: CGFloat = 6
        static let badge: CGFloat = 3
        static let pill: CGFloat = 12
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Radii.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.card)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.sectionHeader)
            .foregroundColor(Theme.Colors.textSecondary)
            .tracking(1)
            .textCase(.uppercase)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
    func sectionHeaderStyle() -> some View { modifier(SectionHeaderStyle()) }
}

// MARK: - Sort Toggle

enum SortOrder: String, CaseIterable {
    case date = "Date"
    case amount = "Amount"
}

struct SortToggle: View {
    @Binding var order: SortOrder

    var body: some View {
        Button {
            order = order == .date ? .amount : .date
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(order.rawValue)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.Colors.surface)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Formatters

enum Formatters {
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()

    private static let currencyShortFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    static func currency(_ value: Double, decimals: Bool = true) -> String {
        let f = decimals ? currencyFormatter : currencyShortFormatter
        return f.string(from: NSNumber(value: abs(value))) ?? "$0"
    }

    static func shortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count >= 3, let m = Int(parts[1]), let d = Int(parts[2]),
              m >= 1, m <= 12 else { return dateStr }
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return "\(months[m-1]) \(d)"
    }

    static func monthLabel(_ ym: String) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), let y = Int(parts[0]),
              m >= 1, m <= 12 else { return ym }
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return "\(months[m-1]) \(y)"
    }

    static func monthRange(_ start: String, months: Int) -> String {
        let startLabel = monthLabel(start)
        let endLabel = monthLabel(addMonths(start, months - 1))
        return "\(startLabel) – \(endLabel)"
    }

    static func addMonths(_ ym: String, _ n: Int) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2, var m = Int(parts[1]), var y = Int(parts[0]) else { return ym }
        m += n
        while m > 12 { m -= 12; y += 1 }
        while m < 1 { m += 12; y -= 1 }
        return String(format: "%04d-%02d", y, m)
    }
}

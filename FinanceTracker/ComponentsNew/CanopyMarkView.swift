import SwiftUI

enum CanopyVariant {
    case color
    case white
}

struct CanopyMarkView: View {
    var size: CGFloat = 32
    var variant: CanopyVariant = .color

    private var scale: CGFloat { size / 80 }

    var body: some View {
        ZStack {
            // Trunks (behind canopy)
            trunk(x: 40, y1: 42, y2: 76, color: trunkColor(0))
            trunk(x: 27, y1: 64, y2: 76, color: trunkColor(1))
            trunk(x: 53, y1: 64, y2: 76, color: trunkColor(2))

            // Canopy circles
            canopyCircle(cx: 40, cy: 22, color: circleColor(0), opacity: circleOpacity(0))
            canopyCircle(cx: 27, cy: 44, color: circleColor(1), opacity: circleOpacity(1))
            canopyCircle(cx: 53, cy: 44, color: circleColor(2), opacity: circleOpacity(2))
        }
        .frame(width: size, height: size * (82.0 / 80.0))
    }

    private func trunk(x: CGFloat, y1: CGFloat, y2: CGFloat, color: Color) -> some View {
        let trunkOpacity: Double = variant == .white ? 0.25 : 0.5
        return Rectangle()
            .fill(color.opacity(trunkOpacity))
            .frame(width: 2.5 * scale, height: (y2 - y1) * scale)
            .position(x: x * scale, y: ((y1 + y2) / 2) * scale)
    }

    private func canopyCircle(cx: CGFloat, cy: CGFloat, color: Color, opacity: Double) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: 40 * scale, height: 40 * scale)
            .position(x: cx * scale, y: cy * scale)
    }

    private func trunkColor(_ index: Int) -> Color {
        if variant == .white { return .white }
        let colors: [Color] = [
            Color(hex: "#0d9488"),
            Color(hex: "#14b8a6"),
            Color(hex: "#22c55e"),
        ]
        return colors[index]
    }

    private func circleColor(_ index: Int) -> Color {
        if variant == .white { return .white }
        let colors: [Color] = [
            Color(hex: "#0d9488"),
            Color(hex: "#14b8a6"),
            Color(hex: "#22c55e"),
        ]
        return colors[index]
    }

    private func circleOpacity(_ index: Int) -> Double {
        if variant == .white {
            return [0.85, 0.60, 0.50][index]
        }
        return 0.65
    }
}

struct CanopyWordmarkView: View {
    var size: CGFloat = 22

    var body: some View {
        Text("Canopy")
            .font(.system(size: size, weight: .semibold, design: .serif))
            .foregroundColor(Theme.Colors.text)
    }
}

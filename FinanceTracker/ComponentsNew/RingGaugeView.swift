import SwiftUI

struct RingGaugeView: View {
    let value: Double
    let maxValue: Double
    var size: CGFloat = 80
    var strokeWidth: CGFloat = 8
    var color: Color = Theme.Colors.accent
    var trackColor: Color = Theme.Colors.subtleBg
    var clockwise: Bool = true
    var content: (() -> AnyView)? = nil

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: clockwise ? 1 : -1, y: 1)
                .animation(.easeOut(duration: 0.5), value: progress)

            // Content
            if let content = content {
                content()
            }
        }
        .frame(width: size, height: size)
    }
}

// Extension to create RingGaugeView with content
extension RingGaugeView {
    init(
        value: Double,
        maxValue: Double,
        size: CGFloat = 80,
        strokeWidth: CGFloat = 8,
        color: Color = Theme.Colors.accent,
        trackColor: Color = Theme.Colors.subtleBg,
        clockwise: Bool = true,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.value = value
        self.maxValue = maxValue
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
        self.trackColor = trackColor
        self.clockwise = clockwise
        self.content = { AnyView(content()) }
    }
}

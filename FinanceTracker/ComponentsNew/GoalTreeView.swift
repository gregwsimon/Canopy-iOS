import SwiftUI

enum TreeStage {
    case seed, sprout, sapling, tree, canopy

    var color: Color {
        switch self {
        case .seed: return Theme.Colors.textMuted
        case .sprout: return Theme.Colors.tealLight
        case .sapling: return Theme.Colors.teal
        case .tree: return Theme.Colors.brandGreen
        case .canopy: return Theme.Colors.brandGreen
        }
    }
}

struct GoalTreeView: View {
    let progress: Double
    var goalType: String = ""
    var size: CGFloat = 24

    private var stage: TreeStage {
        if goalType == "category_limit" {
            if progress >= 1 { return .seed }
            if progress > 0.75 { return .sprout }
            if progress > 0.5 { return .sapling }
            return .canopy
        }
        if progress >= 1 { return .canopy }
        if progress > 0.5 { return .tree }
        if progress > 0.25 { return .sapling }
        if progress > 0 { return .sprout }
        return .seed
    }

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width
            let scale = s / 32.0
            let stg = stage
            let c = stg.color

            switch stg {
            case .seed:
                // Ground ellipse
                let groundRect = CGRect(
                    x: 10 * scale, y: 22 * scale,
                    width: 12 * scale, height: 4 * scale
                )
                context.opacity = 0.5
                context.fill(
                    Path(ellipseIn: groundRect),
                    with: .color(Color(hex: "#d4c5a9"))
                )
                // Seed circle
                context.opacity = 0.6
                let seedRect = CGRect(
                    x: 13 * scale, y: 19 * scale,
                    width: 6 * scale, height: 6 * scale
                )
                context.fill(
                    Path(ellipseIn: seedRect),
                    with: .color(c)
                )

            case .sprout:
                // Stem
                var stem = Path()
                stem.move(to: CGPoint(x: 16 * scale, y: 26 * scale))
                stem.addLine(to: CGPoint(x: 16 * scale, y: 16 * scale))
                context.stroke(
                    stem,
                    with: .color(c),
                    style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round)
                )
                // Left leaf
                context.opacity = 0.7
                let leftLeaf = rotatedEllipse(
                    cx: 12.5 * scale, cy: 15 * scale,
                    rx: 3.5 * scale, ry: 2 * scale,
                    angle: -.pi / 9
                )
                context.fill(leftLeaf, with: .color(c))
                // Right leaf
                context.opacity = 0.6
                let rightLeaf = rotatedEllipse(
                    cx: 19.5 * scale, cy: 14 * scale,
                    rx: 3 * scale, ry: 1.8 * scale,
                    angle: .pi / 7.2
                )
                context.fill(rightLeaf, with: .color(c))

            case .sapling:
                // Stem
                context.opacity = 0.6
                var stem = Path()
                stem.move(to: CGPoint(x: 16 * scale, y: 28 * scale))
                stem.addLine(to: CGPoint(x: 16 * scale, y: 12 * scale))
                context.stroke(
                    stem,
                    with: .color(c),
                    style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round)
                )
                // Top canopy
                context.opacity = 0.5
                context.fill(
                    Path(ellipseIn: CGRect(x: 10 * scale, y: 4 * scale, width: 12 * scale, height: 12 * scale)),
                    with: .color(c)
                )
                // Left canopy
                context.opacity = 0.4
                context.fill(
                    Path(ellipseIn: CGRect(x: 9 * scale, y: 8 * scale, width: 8 * scale, height: 8 * scale)),
                    with: .color(c)
                )
                // Right canopy
                context.fill(
                    Path(ellipseIn: CGRect(x: 15 * scale, y: 8 * scale, width: 8 * scale, height: 8 * scale)),
                    with: .color(c)
                )

            case .tree:
                // Trunk
                context.opacity = 0.5
                var trunk = Path()
                trunk.move(to: CGPoint(x: 16 * scale, y: 28 * scale))
                trunk.addLine(to: CGPoint(x: 16 * scale, y: 10 * scale))
                context.stroke(
                    trunk,
                    with: .color(c),
                    style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round)
                )
                // Top canopy
                context.opacity = 0.55
                context.fill(
                    Path(ellipseIn: CGRect(x: 9 * scale, y: 2 * scale, width: 14 * scale, height: 14 * scale)),
                    with: .color(c)
                )
                // Left canopy
                context.opacity = 0.45
                context.fill(
                    Path(ellipseIn: CGRect(x: 5.5 * scale, y: 6.5 * scale, width: 11 * scale, height: 11 * scale)),
                    with: .color(c)
                )
                // Right canopy
                context.fill(
                    Path(ellipseIn: CGRect(x: 15.5 * scale, y: 6.5 * scale, width: 11 * scale, height: 11 * scale)),
                    with: .color(c)
                )

            case .canopy:
                let teal = Theme.Colors.teal
                let tealLight = Theme.Colors.tealLight
                let green = Theme.Colors.brandGreen

                // Center trunk
                context.opacity = 0.5
                var t1 = Path()
                t1.move(to: CGPoint(x: 16 * scale, y: 28 * scale))
                t1.addLine(to: CGPoint(x: 16 * scale, y: 14 * scale))
                context.stroke(t1, with: .color(teal), style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
                // Left trunk
                context.opacity = 0.4
                var t2 = Path()
                t2.move(to: CGPoint(x: 11 * scale, y: 24 * scale))
                t2.addLine(to: CGPoint(x: 11 * scale, y: 18 * scale))
                context.stroke(t2, with: .color(tealLight), style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
                // Right trunk
                var t3 = Path()
                t3.move(to: CGPoint(x: 21 * scale, y: 24 * scale))
                t3.addLine(to: CGPoint(x: 21 * scale, y: 18 * scale))
                context.stroke(t3, with: .color(green), style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
                // Three overlapping circle canopies (brand mark)
                context.opacity = 0.65
                context.fill(
                    Path(ellipseIn: CGRect(x: 9.5 * scale, y: 1.5 * scale, width: 13 * scale, height: 13 * scale)),
                    with: .color(teal)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: 4.5 * scale, y: 7.5 * scale, width: 13 * scale, height: 13 * scale)),
                    with: .color(tealLight)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: 14.5 * scale, y: 7.5 * scale, width: 13 * scale, height: 13 * scale)),
                    with: .color(green)
                )
            }
        }
        .frame(width: size, height: size)
    }

    private func rotatedEllipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, angle: CGFloat) -> Path {
        var path = Path()
        let transform = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: angle)
        path.addEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: transform)
        return path
    }
}

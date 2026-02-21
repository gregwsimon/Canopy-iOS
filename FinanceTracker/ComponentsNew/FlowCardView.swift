import SwiftUI

struct FlowCardView: View {
    let netIncome: Double
    let fixedTotal: Double
    let flexibleTotal: Double
    var savingsTarget: Double = 0
    var spreadTotal: Double = 0
    var healthcareTotal: Double = 0
    var healthcarePaidTotal: Double = 0
    var healthcareAwaitingTotal: Double = 0
    var creditBadgeCount: Int = 0
    var creditBadgeTotal: Double = 0
    var pendingReturns: Double = 0
    var expectedFixed: Double? = nil
    var actualFixed: Double? = nil
    var onNodeTap: ((String) -> Void)? = nil
    var onCreditBadgeTap: (() -> Void)? = nil
    var onRefundTap: (() -> Void)? = nil

    private static let healthcareColor = Color(hex: "#ec4899")

    private var unspent: Double {
        max(netIncome - fixedTotal - savingsTarget - spreadTotal - healthcareTotal - flexibleTotal, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CASH FLOW")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            if netIncome > 0 {
                flowChart

                // Callout items below the Sankey (not positioned in Canvas)
                if healthcarePaidTotal > 0 || pendingReturns > 0 {
                    Divider()
                        .padding(.top, 2)

                    VStack(spacing: 6) {
                        if pendingReturns > 0 {
                            Button { onRefundTap?() } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Theme.Colors.purple)
                                        .frame(width: 7, height: 7)
                                    Text("Refunds")
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(Formatters.currency(pendingReturns, decimals: false))
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(Theme.Colors.purple.opacity(0.5))
                                }
                                .foregroundColor(Theme.Colors.purple)
                            }
                            .buttonStyle(.plain)
                        }

                        if healthcarePaidTotal > 0 {
                            Button { onNodeTap?("healthcare") } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Self.healthcareColor)
                                        .frame(width: 7, height: 7)
                                    Text("Healthcare")
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(healthcareAwaitingTotal > 0 ? Formatters.currency(healthcareAwaitingTotal, decimals: false) : "Settled")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(Self.healthcareColor.opacity(0.5))
                                }
                                .foregroundColor(Self.healthcareColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("No flow data")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var flowChart: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 190
            let barW: CGFloat = 10
            let leftBarX: CGFloat = 74
            let rightBarX: CGFloat = w - 100

            let rightSpanH: CGFloat = h * 0.85
            let rightSpanTop: CGFloat = (h - rightSpanH) / 2

            // Fractions of net income (flow categories only — healthcare/pending are callouts below)
            let savFrac = savingsTarget > 0 ? min(savingsTarget / netIncome, 1.0) : 0
            let spreadFrac = spreadTotal > 0 ? min(spreadTotal / netIncome, max(1.0 - savFrac, 0)) : 0
            let fixedFrac = min(fixedTotal / netIncome, max(1.0 - savFrac - spreadFrac, 0))
            let flexFrac = min(flexibleTotal / netIncome, max(1.0 - savFrac - spreadFrac - fixedFrac, 0))
            let hcFracForUnspent = healthcareTotal > 0 ? min(healthcareTotal / netIncome, max(1.0 - savFrac - spreadFrac - fixedFrac - flexFrac, 0)) : 0
            let unspentFrac = max(1.0 - savFrac - spreadFrac - fixedFrac - flexFrac - hcFracForUnspent, 0)

            // Right bar heights (scaled to fit within rightSpanH)
            let bars = Self.scaledBarLayout(
                greenH: rightSpanH, greenTop: rightSpanTop,
                fixedFrac: fixedFrac, savFrac: savFrac,
                spreadFrac: spreadFrac,
                flexFrac: flexFrac, unspentFrac: unspentFrac
            )
            let greyH = bars.greyH
            let tealH = bars.tealH
            let spreadH = bars.spreadH
            let blueH = bars.blueH
            let unspentH = bars.unspentH
            let greyTop: CGFloat = bars.greyTop
            let tealTop: CGFloat = bars.tealTop
            let spreadTop: CGFloat = bars.spreadTop
            let blueTop: CGFloat = bars.blueTop
            let unspentTop: CGFloat = bars.unspentTop

            let flowLastBot = unspentH > 0 ? unspentTop + unspentH : blueTop + blueH

            // Left green bar: compact and centered, flows fan out
            let rightActualSpan = flowLastBot - greyTop
            let greenH = rightActualSpan * 0.8
            let greenTop = greyTop + (rightActualSpan - greenH) / 2

            // Inline credit badge segment on income bar (always visible)
            let creditSegH: CGFloat = 12.0
            let creditSegTop = greenTop + greenH - creditSegH

            // Source segments on left green bar
            let srcSavTop = greenTop
            let srcFixedTop = greenTop + greenH * savFrac
            let srcSpreadTop = greenTop + greenH * (savFrac + fixedFrac)
            let srcFlexTop = greenTop + greenH * (savFrac + fixedFrac + spreadFrac)
            let srcUnspentTop = greenTop + greenH * (savFrac + fixedFrac + spreadFrac + flexFrac)

            // Right label positioning with collision avoidance
            let rightLabelX = rightBarX + barW + 8 + (w - rightBarX - barW - 8) / 2
            let rightLabelW = w - rightBarX - barW - 8

            let adjusted = Self.resolveOverlaps(
                fixed: greyTop + greyH / 2,
                savings: tealH > 0 ? tealTop + tealH / 2 : -1,
                spread: spreadH > 0 ? spreadTop + spreadH / 2 : -1,
                flexible: blueTop + blueH / 2,
                unspent: unspentH > 0 ? unspentTop + unspentH / 2 : -1,
                maxY: h - 14
            )

            // Canvas: bars + flow bands
            Canvas { ctx, _ in
                ctx.fill(
                    Path(roundedRect: CGRect(x: leftBarX, y: greenTop, width: barW, height: greenH), cornerRadius: 3),
                    with: .color(Theme.Colors.success)
                )

                // Amber credit sub-segment at bottom of income bar
                ctx.fill(
                    Path(roundedRect: CGRect(x: leftBarX, y: creditSegTop, width: barW, height: creditSegH), cornerRadius: 3),
                    with: .color(Theme.Colors.amber)
                )

                if tealH > 0 {
                    ctx.fill(
                        Path(roundedRect: CGRect(x: rightBarX, y: tealTop, width: barW, height: tealH), cornerRadius: 3),
                        with: .color(Theme.Colors.teal)
                    )
                }

                if spreadH > 0 {
                    ctx.fill(
                        Path(roundedRect: CGRect(x: rightBarX, y: spreadTop, width: barW, height: spreadH), cornerRadius: 3),
                        with: .color(Theme.Colors.rose)
                    )
                }

                ctx.fill(
                    Path(roundedRect: CGRect(x: rightBarX, y: greyTop, width: barW, height: greyH), cornerRadius: 3),
                    with: .color(Theme.Colors.textSecondary)
                )

                ctx.fill(
                    Path(roundedRect: CGRect(x: rightBarX, y: blueTop, width: barW, height: blueH), cornerRadius: 3),
                    with: .color(Theme.Colors.flexBlue)
                )

                if unspentH > 0 {
                    ctx.stroke(
                        Path(roundedRect: CGRect(x: rightBarX, y: unspentTop, width: barW, height: unspentH), cornerRadius: 3),
                        with: .color(Theme.Colors.textDisabled),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                }

                // Flow bands
                if tealH > 0 {
                    drawFlowBand(ctx: ctx, fromX: leftBarX + barW, fromTopY: srcSavTop, fromH: greenH * savFrac, toX: rightBarX, toTopY: tealTop, toH: tealH, color: Theme.Colors.teal.opacity(0.10))
                }

                if spreadH > 0 {
                    drawFlowBand(ctx: ctx, fromX: leftBarX + barW, fromTopY: srcSpreadTop, fromH: greenH * spreadFrac, toX: rightBarX, toTopY: spreadTop, toH: spreadH, color: Theme.Colors.rose.opacity(0.10))
                }

                drawFlowBand(ctx: ctx, fromX: leftBarX + barW, fromTopY: srcFixedTop, fromH: greenH * fixedFrac, toX: rightBarX, toTopY: greyTop, toH: greyH, color: Theme.Colors.textSecondary.opacity(0.12))

                drawFlowBand(ctx: ctx, fromX: leftBarX + barW, fromTopY: srcFlexTop, fromH: greenH * flexFrac, toX: rightBarX, toTopY: blueTop, toH: blueH, color: Theme.Colors.flexBlue.opacity(0.10))

                if unspentH > 0 {
                    drawFlowBand(ctx: ctx, fromX: leftBarX + barW, fromTopY: srcUnspentTop, fromH: greenH * unspentFrac, toX: rightBarX, toTopY: unspentTop, toH: unspentH, color: Theme.Colors.textDisabled.opacity(0.08))
                }
            }
            .frame(width: w, height: h)
            .allowsHitTesting(false)

            // Net Income label
            VStack(alignment: .trailing, spacing: 2) {
                Text("Net Income")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                Text(Formatters.currency(netIncome, decimals: false))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(width: leftBarX - 8, alignment: .trailing)
            .contentShape(Rectangle())
            .onTapGesture { onNodeTap?("income") }
            .position(x: (leftBarX - 8) / 2, y: greenTop + greenH / 2)

            // Fixed label
            VStack(alignment: .leading, spacing: 1) {
                Text("Fixed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                HStack(spacing: 4) {
                    Text(Formatters.currency(fixedTotal, decimals: false))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)
                    if let actual = actualFixed, let expected = expectedFixed, expected > 0 {
                        let delta = actual - expected
                        if delta > 10 {
                            Text("↑ \(Formatters.currency(delta, decimals: false))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.Colors.error)
                        } else if delta < -10 {
                            Text("↓ \(Formatters.currency(delta, decimals: false))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.Colors.success)
                        }
                    }
                }
            }
            .frame(width: rightLabelW, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onNodeTap?("fixed") }
            .position(x: rightLabelX, y: adjusted.fixedY)

            // Saving label
            if tealH > 0 {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Saving")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.teal)
                    Text(Formatters.currency(savingsTarget, decimals: false))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.teal.opacity(0.7))
                }
                .frame(width: rightLabelW, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onNodeTap?("savings") }
                .position(x: rightLabelX, y: adjusted.savingsY)
            }

            // Payoff label
            if spreadH > 0 {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Payoff")
                        .font(.system(size: 11, weight: .medium))
                    Text(Formatters.currency(spreadTotal, decimals: false))
                        .font(.system(size: 10))
                }
                .foregroundColor(Theme.Colors.rose)
                .frame(width: rightLabelW, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onNodeTap?("spread") }
                .position(x: rightLabelX, y: adjusted.spreadY)
            }

            // Flexible label
            VStack(alignment: .leading, spacing: 1) {
                Text("Flexible")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                Text(Formatters.currency(flexibleTotal, decimals: false))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(width: rightLabelW, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onNodeTap?("flexible") }
            .position(x: rightLabelX, y: adjusted.flexibleY)

            // Unspent label
            if unspentH > 0 {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Unspent")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textDisabled)
                    Text(Formatters.currency(unspent, decimals: false))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textDisabled)
                }
                .frame(width: rightLabelW, alignment: .leading)
                .position(x: rightLabelX, y: adjusted.unspentY)
            }

            // Credit segment tappable label (left side, next to amber bar)
            Button(action: { onCreditBadgeTap?() }) {
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 2) {
                        Text(creditBadgeCount > 0 ? "\(creditBadgeCount) Credit\(creditBadgeCount == 1 ? "" : "s")" : "Credits")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    if creditBadgeCount > 0 {
                        Text(Formatters.currency(creditBadgeTotal, decimals: false))
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(Color(hex: "#b45309"))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: leftBarX - 8, alignment: .trailing)
            .position(x: (leftBarX - 8) / 2, y: creditSegTop + creditSegH / 2)
        }
        .frame(height: 190)
    }

    // MARK: - Bar layout (scaled to fit)

    private struct BarLayout {
        let greyH: CGFloat, tealH: CGFloat, spreadH: CGFloat, blueH: CGFloat, unspentH: CGFloat
        let greyTop: CGFloat, tealTop: CGFloat, spreadTop: CGFloat, blueTop: CGFloat, unspentTop: CGFloat
    }

    private static func scaledBarLayout(
        greenH: CGFloat, greenTop: CGFloat,
        fixedFrac: CGFloat, savFrac: CGFloat,
        spreadFrac: CGFloat,
        flexFrac: CGFloat, unspentFrac: CGFloat
    ) -> BarLayout {
        let barGap: CGFloat = 4
        let minBarH: CGFloat = 10
        var greyH = max(minBarH, greenH * fixedFrac)
        var tealH: CGFloat = savFrac > 0 ? max(minBarH, greenH * savFrac) : 0
        var spreadH: CGFloat = spreadFrac > 0 ? max(minBarH, greenH * spreadFrac) : 0
        var blueH = max(minBarH, greenH * flexFrac)
        var unspentH: CGFloat = unspentFrac > 0.02 ? max(minBarH, greenH * unspentFrac) : 0

        let activeBarCount = [true, tealH > 0, spreadH > 0, true, unspentH > 0].filter { $0 }.count
        let totalGapSpace = CGFloat(activeBarCount - 1) * barGap
        let totalBarH = greyH + tealH + spreadH + blueH + unspentH
        if totalBarH + totalGapSpace > greenH {
            let availableForBars = greenH - totalGapSpace
            let scale = availableForBars / totalBarH
            greyH = max(minBarH, greyH * scale)
            if tealH > 0 { tealH = max(minBarH, tealH * scale) }
            if spreadH > 0 { spreadH = max(minBarH, spreadH * scale) }
            blueH = max(minBarH, blueH * scale)
            if unspentH > 0 { unspentH = max(minBarH, unspentH * scale) }
        }

        let tealTop = greenTop
        let greyTop = tealTop + (tealH > 0 ? tealH + barGap : 0)
        let spreadTop = greyTop + greyH + barGap
        let blueTop = spreadTop + (spreadH > 0 ? spreadH + barGap : 0)
        let unspentTop = blueTop + blueH + (unspentH > 0 ? barGap : 0)

        return BarLayout(
            greyH: greyH, tealH: tealH, spreadH: spreadH, blueH: blueH, unspentH: unspentH,
            greyTop: greyTop, tealTop: tealTop, spreadTop: spreadTop, blueTop: blueTop, unspentTop: unspentTop
        )
    }

    // MARK: - Label collision avoidance

    private struct AdjustedLabels {
        var fixedY: CGFloat
        var savingsY: CGFloat
        var spreadY: CGFloat
        var flexibleY: CGFloat
        var unspentY: CGFloat
    }

    private static func resolveOverlaps(fixed: CGFloat, savings: CGFloat, spread: CGFloat, flexible: CGFloat, unspent: CGFloat, maxY: CGFloat = .infinity) -> AdjustedLabels {
        let minGap: CGFloat = 28

        var centers: [(index: Int, y: CGFloat)] = []
        if savings >= 0 { centers.append((1, savings)) }
        centers.append((0, fixed))
        if spread >= 0 { centers.append((5, spread)) }
        centers.append((2, flexible))
        if unspent >= 0 { centers.append((3, unspent)) }

        // Push apart labels that are too close (top-down)
        for i in 1..<centers.count {
            if centers[i].y - centers[i - 1].y < minGap {
                centers[i].y = centers[i - 1].y + minGap
            }
        }

        // Clamp last label to maxY, then push earlier labels up if needed
        if let last = centers.last, last.y > maxY {
            centers[centers.count - 1].y = maxY
            for i in stride(from: centers.count - 2, through: 0, by: -1) {
                if centers[i + 1].y - centers[i].y < minGap {
                    centers[i].y = centers[i + 1].y - minGap
                }
            }
        }

        var result = AdjustedLabels(fixedY: fixed, savingsY: savings, spreadY: spread, flexibleY: flexible, unspentY: unspent)
        for c in centers {
            switch c.index {
            case 0: result.fixedY = c.y
            case 1: result.savingsY = c.y
            case 2: result.flexibleY = c.y
            case 3: result.unspentY = c.y
            case 5: result.spreadY = c.y
            default: break
            }
        }
        return result
    }

    private func drawFlowBand(ctx: GraphicsContext, fromX: CGFloat, fromTopY: CGFloat, fromH: CGFloat, toX: CGFloat, toTopY: CGFloat, toH: CGFloat, color: Color) {
        var path = Path()
        let midX = (fromX + toX) / 2

        path.move(to: CGPoint(x: fromX, y: fromTopY))
        path.addCurve(to: CGPoint(x: toX, y: toTopY), control1: CGPoint(x: midX, y: fromTopY), control2: CGPoint(x: midX, y: toTopY))
        path.addLine(to: CGPoint(x: toX, y: toTopY + toH))
        path.addCurve(to: CGPoint(x: fromX, y: fromTopY + fromH), control1: CGPoint(x: midX, y: toTopY + toH), control2: CGPoint(x: midX, y: fromTopY + fromH))
        path.closeSubpath()

        ctx.fill(path, with: .color(color))
    }
}

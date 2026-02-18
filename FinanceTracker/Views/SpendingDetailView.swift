import SwiftUI

struct SpendingDetailView: View {
    let title: String
    let barLabel: String
    let items: [CategoryTotal]            // detailed (all subcategories)
    let groupedItems: [CategoryTotal]     // parent-level groups for Sankey
    let budget: Double
    let barColor: String
    let month: String
    var fixedFilter: Bool? = nil
    @State private var selectedCategory: CategoryTotal?
    @State private var displayMode: DisplayMode = .sankey

    enum DisplayMode: String, CaseIterable {
        case sankey, treemap, bars
    }

    private var sortedGrouped: [CategoryTotal] {
        groupedItems.sorted { $0.amount > $1.amount }
    }

    private var totalSpent: Double {
        groupedItems.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        GeometryReader { geo in
            let contentH = geo.size.height

            switch displayMode {
            case .sankey:
                sankeyChart(availableHeight: contentH)
                    .padding(.horizontal)
            case .treemap:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow
                        treemapView
                    }
                    .padding()
                }
            case .bars:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryRow
                        progressBarsView
                    }
                    .padding()
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Display", selection: $displayMode) {
                    Image(systemName: "arrow.triangle.branch").tag(DisplayMode.sankey)
                    Image(systemName: "square.grid.2x2.fill").tag(DisplayMode.treemap)
                    Image(systemName: "chart.bar.fill").tag(DisplayMode.bars)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
        .sheet(item: $selectedCategory) { cat in
            CategoryTransactionsSheet(
                categoryName: cat.name,
                categoryId: cat.id,
                month: month,
                fixedFilter: fixedFilter
            )
        }
    }

    // MARK: - Summary Row (for treemap/bars modes)

    private var summaryRow: some View {
        HStack {
            Text("Total")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            Text(Formatters.currency(totalSpent, decimals: false))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.Colors.text)
        }
        .cardStyle()
    }

    // MARK: - Treemap Mode

    private var treemapView: some View {
        GeometryReader { geo in
            TreemapLayout(
                categories: sortedGrouped,
                total: totalSpent,
                width: geo.size.width,
                onCategoryTap: { cat in selectedCategory = cat }
            )
        }
        .frame(height: TreemapLayout.height(for: min(sortedGrouped.count, 10)))
    }

    // MARK: - Progress Bars Mode

    private var progressBarsView: some View {
        VStack(spacing: 0) {
            ForEach(sortedGrouped) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: item.color))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.Colors.text)
                        }
                        Spacer()
                        Text(Formatters.currency(item.amount, decimals: false))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.text)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.Colors.subtleBg)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: item.color))
                                .frame(width: geo.size.width * min(item.amount / max(totalSpent, 1), 1), height: 6)
                        }
                    }
                    .frame(height: 6)
                    let pct = totalSpent > 0 ? Int(item.amount / totalSpent * 100) : 0
                    Text("\(pct)% of \(barLabel.lowercased()) spending")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(12)
                .contentShape(Rectangle())
                .onTapGesture { selectedCategory = item }

                if item.id != sortedGrouped.last?.id {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Sankey Chart (fits available height)

    private func sankeyChart(availableHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let layout = computeLayout(width: geo.size.width, availableHeight: availableHeight)

            Canvas { ctx, _ in
                drawSankey(ctx: ctx, layout: layout)
            }
            .frame(width: geo.size.width, height: availableHeight)
            .allowsHitTesting(false)

            // Tappable label overlays
            ForEach(Array(layout.bars.enumerated()), id: \.offset) { idx, bar in
                Button {
                    if !bar.isRemaining {
                        selectedCategory = sortedGrouped[idx]
                    }
                } label: {
                    HStack(spacing: 4) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(bar.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(bar.isRemaining ? Theme.Colors.textMuted : Theme.Colors.text)
                            Text(Formatters.currency(bar.amount, decimals: false))
                                .font(.system(size: 10))
                                .foregroundColor(bar.isRemaining ? Color(hex: "#bbb") : Theme.Colors.textSecondary)
                        }
                        if !bar.isRemaining {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundColor(Theme.Colors.textDisabled)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: layout.labelWidth, alignment: .leading)
                .position(x: layout.labelX + layout.labelWidth / 2, y: bar.labelMidY)
            }

            // Percentage labels inside flow bands (just left of right bar)
            ForEach(Array(layout.bars.enumerated()), id: \.offset) { _, bar in
                let pct = budget > 0 ? Int(bar.amount / budget * 100) : 0
                if pct >= 1 {
                    Text("\(pct)%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: bar.color).opacity(0.5))
                        .position(x: layout.rightBarX - 18, y: bar.top + bar.rawH / 2)
                }
            }

            // Left bar label
            VStack(spacing: 1) {
                Text(barLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                Text(Formatters.currency(budget, decimals: false))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Colors.text)
            }
            .position(x: layout.leftBarX + layout.barW + 36, y: layout.leftBarTop + layout.leftBarH / 2)
        }
        .frame(height: availableHeight)
    }

    // MARK: - Layout Calculation

    private struct BarInfo {
        let name: String
        let amount: Double
        let color: String
        let isRemaining: Bool
        var rawH: CGFloat
        var slotH: CGFloat
        var top: CGFloat = 0
        var labelMidY: CGFloat = 0
        var srcTop: CGFloat = 0
        var srcBot: CGFloat = 0
    }

    private struct SankeyLayout {
        let bars: [BarInfo]
        let totalHeight: CGFloat
        let leftBarX: CGFloat
        let leftBarTop: CGFloat
        let leftBarH: CGFloat
        let rightBarX: CGFloat
        let barW: CGFloat
        let labelX: CGFloat
        let labelWidth: CGFloat
    }

    private func computeLayout(width: CGFloat, availableHeight: CGFloat) -> SankeyLayout {
        let barW: CGFloat = 10
        let leftBarX: CGFloat = 10
        let rightBarX: CGFloat = width * 0.68
        let labelX: CGFloat = rightBarX + barW + 8
        let labelWidth: CGFloat = width - labelX - 8
        let minBarH: CGFloat = 4
        let gap: CGFloat = 2.0
        let topPad: CGFloat = 8.0
        let minSlotH: CGFloat = 32

        let totalAmount = sortedGrouped.reduce(0.0) { $0 + $1.amount }
        let totalGaps = CGFloat(max(sortedGrouped.count - 1, 0)) * gap
        let maxSlotH: CGFloat = 80
        let maxContentH = CGFloat(sortedGrouped.count) * maxSlotH + totalGaps + topPad * 2
        let effectiveH = min(availableHeight, maxContentH)
        let verticalOffset = (availableHeight - effectiveH) / 2
        let usableH = effectiveH - topPad * 2 - totalGaps

        // Proportional slot heights with minimum enforcement
        var slotHeights: [CGFloat] = sortedGrouped.map { item in
            totalAmount > 0 ? CGFloat(item.amount / totalAmount) * usableH : minSlotH
        }
        let belowMin = slotHeights.enumerated().filter { $0.element < minSlotH }
        if !belowMin.isEmpty {
            let deficit = belowMin.reduce(CGFloat(0)) { $0 + (minSlotH - $1.element) }
            let aboveTotal = slotHeights.enumerated()
                .filter { $0.element >= minSlotH }
                .reduce(CGFloat(0)) { $0 + $1.element }
            let shrink = aboveTotal > 0 ? max(aboveTotal - deficit, 0) / aboveTotal : 1
            for i in 0..<slotHeights.count {
                if slotHeights[i] < minSlotH {
                    slotHeights[i] = minSlotH
                } else {
                    slotHeights[i] *= shrink
                }
            }
        }

        var bars: [BarInfo] = sortedGrouped.enumerated().map { i, item in
            let slotH = slotHeights[i]
            let rawH = max(slotH * 0.7, minBarH)
            return BarInfo(
                name: item.name, amount: item.amount, color: item.color,
                isRemaining: false, rawH: rawH, slotH: slotH
            )
        }

        // Position bars (centered vertically)
        var curY = verticalOffset + topPad
        for i in 0..<bars.count {
            bars[i].top = curY + (bars[i].slotH - bars[i].rawH) / 2
            bars[i].labelMidY = curY + bars[i].slotH / 2
            curY += bars[i].slotH + gap
        }

        // Left bar: compact and centered, flows fan out from it
        let firstBarTop = bars.first?.top ?? topPad
        let lastBar = bars.last
        let lastBarBot = (lastBar?.top ?? topPad) + (lastBar?.rawH ?? 0)
        let rightSpan = lastBarBot - firstBarTop
        let leftBarH = rightSpan * 0.8
        let leftBarTop = firstBarTop + (rightSpan - leftBarH) / 2

        // Source positions on left bar (proportional to total spent)
        var srcCur = leftBarTop
        for i in 0..<bars.count {
            bars[i].srcTop = srcCur
            let srcH = CGFloat(bars[i].amount) / max(CGFloat(totalAmount), 1) * leftBarH
            bars[i].srcBot = srcCur + srcH
            srcCur += srcH
        }

        return SankeyLayout(
            bars: bars, totalHeight: availableHeight,
            leftBarX: leftBarX, leftBarTop: leftBarTop, leftBarH: leftBarH,
            rightBarX: rightBarX, barW: barW, labelX: labelX, labelWidth: labelWidth
        )
    }

    // MARK: - Drawing

    private func drawSankey(ctx: GraphicsContext, layout: SankeyLayout) {
        // Left bar
        ctx.fill(
            Path(roundedRect: CGRect(
                x: layout.leftBarX, y: layout.leftBarTop,
                width: layout.barW, height: layout.leftBarH
            ), cornerRadius: 4),
            with: .color(Color(hex: barColor))
        )

        for bar in layout.bars {
            // Flow band
            let opacity: Double = bar.isRemaining ? 0.04 : 0.10
            var bandPath = Path()
            let fromX = layout.leftBarX + layout.barW
            let toX = layout.rightBarX
            let midX = (fromX + toX) / 2

            bandPath.move(to: CGPoint(x: fromX, y: bar.srcTop))
            bandPath.addCurve(
                to: CGPoint(x: toX, y: bar.top),
                control1: CGPoint(x: midX, y: bar.srcTop),
                control2: CGPoint(x: midX, y: bar.top)
            )
            bandPath.addLine(to: CGPoint(x: toX, y: bar.top + bar.rawH))
            bandPath.addCurve(
                to: CGPoint(x: fromX, y: bar.srcBot),
                control1: CGPoint(x: midX, y: bar.top + bar.rawH),
                control2: CGPoint(x: midX, y: bar.srcBot)
            )
            bandPath.closeSubpath()
            ctx.fill(bandPath, with: .color(Color(hex: bar.color).opacity(opacity)))

            // Right bar
            let barRect = CGRect(x: layout.rightBarX, y: bar.top, width: layout.barW, height: bar.rawH)
            if bar.isRemaining {
                ctx.stroke(
                    Path(roundedRect: barRect, cornerRadius: 3),
                    with: .color(Color(hex: "#bbb")),
                    style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                )
            } else {
                ctx.fill(
                    Path(roundedRect: barRect, cornerRadius: 3),
                    with: .color(Color(hex: bar.color))
                )
            }
        }
    }
}

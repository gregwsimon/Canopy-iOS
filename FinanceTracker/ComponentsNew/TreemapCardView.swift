import SwiftUI

struct TreemapCardView: View {
    let categories: [CategoryTotal]
    let totalExpenses: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE IT'S GOING")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            if categories.isEmpty {
                Text("No expenses yet")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                GeometryReader { geo in
                    TreemapLayout(categories: categories, total: totalExpenses, width: geo.size.width)
                }
                .frame(height: TreemapLayout.height(for: categories.count, width: 0))
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Squarified Treemap Layout

struct TreemapLayout: View {
    let categories: [CategoryTotal]
    let total: Double
    let width: CGFloat
    var onCategoryTap: ((CategoryTotal) -> Void)? = nil

    private let gap: CGFloat = 4

    static func height(for itemCount: Int, width: CGFloat = 0) -> CGFloat {
        let count = min(itemCount, 10)
        if count == 0 { return 0 }
        if count <= 2 { return 100 }
        if count <= 4 { return 200 }
        return 340
    }

    var body: some View {
        let sorted = Array(categories.sorted { $0.amount > $1.amount }.prefix(10))
        let totalAmount = sorted.reduce(0.0) { $0 + $1.amount }

        // Give small items a minimum visual weight so they're still readable
        let minAmount = totalAmount * 0.10
        let layoutItems = sorted.map { item in
            item.amount < minAmount
                ? CategoryTotal(id: item.id, name: item.name, amount: minAmount, color: item.color)
                : item
        }
        let layoutTotal = layoutItems.reduce(0.0) { $0 + $1.amount }

        let layoutHeight = Self.height(for: sorted.count, width: width)
        let rects = squarify(
            items: layoutItems,
            totalValue: layoutTotal,
            bounds: CGRect(x: 0, y: 0, width: width, height: layoutHeight)
        )

        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(sorted, rects).enumerated()), id: \.element.0.id) { index, pair in
                let (item, rect) = pair
                let pct = total > 0 ? item.amount / total : 0
                let insetRect = rect.insetBy(dx: gap / 2, dy: gap / 2)

                TreemapBlock(item: item, pct: pct)
                    .frame(width: max(insetRect.width, 0), height: max(insetRect.height, 0))
                    .position(x: insetRect.midX, y: insetRect.midY)
                    .onTapGesture { onCategoryTap?(item) }
            }
        }
        .frame(width: width, height: layoutHeight, alignment: .topLeading)
    }

    private func squarify(items: [CategoryTotal], totalValue: Double, bounds: CGRect) -> [CGRect] {
        guard !items.isEmpty, totalValue > 0, bounds.width > 0, bounds.height > 0 else {
            return items.map { _ in .zero }
        }

        var result = [CGRect](repeating: .zero, count: items.count)
        var remaining = bounds
        var i = 0

        while i < items.count {
            let isWide = remaining.width >= remaining.height
            let sideLength = isWide ? remaining.height : remaining.width

            var strip: [Int] = [i]
            var stripValue = items[i].amount
            var bestWorst = worstAspectRatio(
                strip: [items[i].amount],
                stripTotal: stripValue,
                sideLength: sideLength,
                areaScale: Double(remaining.width * remaining.height) / remainingValue(items: items, from: i, totalValue: totalValue, bounds: bounds)
            )

            var j = i + 1
            while j < items.count {
                let candidate = items[j].amount
                let newStripValue = stripValue + candidate
                var newValues = strip.map { items[$0].amount }
                newValues.append(candidate)

                let newWorst = worstAspectRatio(
                    strip: newValues,
                    stripTotal: newStripValue,
                    sideLength: sideLength,
                    areaScale: Double(remaining.width * remaining.height) / remainingValue(items: items, from: i, totalValue: totalValue, bounds: bounds)
                )

                if newWorst > bestWorst { break }

                strip.append(j)
                stripValue += candidate
                bestWorst = newWorst
                j += 1
            }

            let remValue = remainingValue(items: items, from: i, totalValue: totalValue, bounds: bounds)
            let stripFraction = stripValue / remValue
            let stripThickness: CGFloat

            if isWide {
                stripThickness = remaining.width * CGFloat(stripFraction)
                var y = remaining.minY
                for idx in strip {
                    let itemFrac = items[idx].amount / stripValue
                    let h = remaining.height * CGFloat(itemFrac)
                    result[idx] = CGRect(x: remaining.minX, y: y, width: stripThickness, height: h)
                    y += h
                }
                remaining = CGRect(
                    x: remaining.minX + stripThickness,
                    y: remaining.minY,
                    width: remaining.width - stripThickness,
                    height: remaining.height
                )
            } else {
                stripThickness = remaining.height * CGFloat(stripFraction)
                var x = remaining.minX
                for idx in strip {
                    let itemFrac = items[idx].amount / stripValue
                    let w = remaining.width * CGFloat(itemFrac)
                    result[idx] = CGRect(x: x, y: remaining.minY, width: w, height: stripThickness)
                    x += w
                }
                remaining = CGRect(
                    x: remaining.minX,
                    y: remaining.minY + stripThickness,
                    width: remaining.width,
                    height: remaining.height - stripThickness
                )
            }

            i = j
        }

        return result
    }

    private func remainingValue(items: [CategoryTotal], from index: Int, totalValue: Double, bounds: CGRect) -> Double {
        var sum = 0.0
        for k in index..<items.count { sum += items[k].amount }
        return max(sum, 0.001)
    }

    private func worstAspectRatio(strip: [Double], stripTotal: Double, sideLength: CGFloat, areaScale: Double) -> Double {
        guard sideLength > 0, stripTotal > 0, areaScale > 0 else { return Double.infinity }
        let stripArea = stripTotal * areaScale
        let thickness = stripArea / Double(sideLength)
        var worst = 0.0
        for val in strip {
            let itemLen = (val * areaScale) / thickness
            guard itemLen > 0, thickness > 0 else { continue }
            let ratio = max(thickness / itemLen, itemLen / thickness)
            worst = max(worst, ratio)
        }
        return worst
    }
}

// MARK: - Treemap Block

struct TreemapBlock: View {
    let item: CategoryTotal
    let pct: Double
    var displayColor: String? = nil

    private var blockColor: Color {
        Color(hex: displayColor ?? item.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(Formatters.currency(item.amount, decimals: false))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(pct >= 0.005 ? "\(Int(pct * 100))%" : "<1%")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(8)
        .background(blockColor)
        .cornerRadius(8)
    }
}

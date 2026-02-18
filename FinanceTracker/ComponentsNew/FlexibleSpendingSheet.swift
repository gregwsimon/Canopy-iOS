import SwiftUI

struct FlexibleSpendingSheet: View {
    let items: [CategoryTotal]
    let total: Double
    var month: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var displayMode: DisplayMode = .treemap
    @State private var selectedCategory: CategoryTotal?

    enum DisplayMode {
        case treemap
        case progressBars
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary
                    HStack {
                        Text("Total")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.currency(total, decimals: false))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.Colors.text)
                    }
                    .padding()
                    .cardStyle()

                    if items.isEmpty {
                        Text("No flexible spending this period")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        switch displayMode {
                        case .treemap:
                            treemapView
                        case .progressBars:
                            progressBarsView
                        }
                    }
                }
                .padding()
            }
            .background(Theme.Colors.background)
            .navigationTitle("Flexible Spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Display", selection: $displayMode) {
                        Image(systemName: "square.grid.2x2.fill").tag(DisplayMode.treemap)
                        Image(systemName: "chart.bar.fill").tag(DisplayMode.progressBars)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .sheet(item: $selectedCategory) { cat in
                CategoryTransactionsSheet(
                    categoryName: cat.name,
                    categoryId: cat.id,
                    month: month
                )
            }
        }
    }

    // MARK: - Treemap Mode

    private var treemapView: some View {
        GeometryReader { geo in
            TreemapLayout(
                categories: sortedItems,
                total: total,
                width: geo.size.width,
                onCategoryTap: { cat in selectedCategory = cat }
            )
        }
        .frame(height: treemapHeight)
    }

    private var treemapHeight: CGFloat {
        TreemapLayout.height(for: min(sortedItems.count, 10))
    }

    // MARK: - Progress Bars Mode

    private var progressBarsView: some View {
        VStack(spacing: 0) {
            ForEach(sortedItems) { item in
                CategoryProgressRow(
                    name: item.name,
                    amount: item.amount,
                    total: total,
                    color: item.color
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedCategory = item }
                if item.id != sortedItems.last?.id {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .cardStyle()
    }

    private var sortedItems: [CategoryTotal] {
        items.sorted { $0.amount > $1.amount }
    }
}

// MARK: - Category Progress Row

private struct CategoryProgressRow: View {
    let name: String
    let amount: Double
    let total: Double
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.text)
                }
                Spacer()
                Text(Formatters.currency(amount, decimals: false))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.Colors.text)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.subtleBg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: color))
                        .frame(width: geo.size.width * min(amount / max(total, 1), 1), height: 6)
                }
            }
            .frame(height: 6)

            let pct = total > 0 ? Int(amount / total * 100) : 0
            Text("\(pct)% of flexible spending")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(12)
    }
}

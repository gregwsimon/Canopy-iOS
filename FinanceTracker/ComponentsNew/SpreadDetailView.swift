import SwiftUI

struct SpreadDetailView: View {
    let items: [SpreadItem]
    let month: String
    var onUpdate: (() -> Void)? = nil

    @State private var editingItem: SpreadItem?

    private var totalMonthly: Double {
        items.reduce(0) { $0 + $1.monthlyPortion }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                HStack {
                    Text("This month's payoff")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(Formatters.currency(totalMonthly, decimals: false))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.rose)
                }
                .cardStyle()

                // Items
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        VStack(spacing: 0) {
                            Button {
                                editingItem = item
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.description)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Theme.Colors.text)
                                        HStack(spacing: 6) {
                                            Text(item.categoryName)
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            Text("·")
                                                .foregroundColor(Theme.Colors.textDisabled)
                                            Text("\(item.months) months from \(Formatters.monthLabel(item.startMonth))")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.Colors.textMuted)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(Formatters.currency(item.monthlyPortion, decimals: false) + "/mo")
                                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                            .foregroundColor(Theme.Colors.rose)
                                        Text("of " + Formatters.currency(item.totalAmount, decimals: false))
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.Colors.textMuted)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textDisabled)
                                        .padding(.leading, 4)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(.plain)

                            if item.id != items.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radii.card)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )

                // Explanation
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.rose)
                    Text("These are large past expenses being absorbed into your monthly budget over time.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding()
                .background(Theme.Colors.roseBg)
                .cornerRadius(Theme.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radii.card)
                        .stroke(Color(hex: "#fecdd3"), lineWidth: 1)
                )
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("Payoffs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingItem) { item in
            SpreadEditSheet(item: item, onSaved: {
                editingItem = nil
                onUpdate?()
            })
        }
    }
}

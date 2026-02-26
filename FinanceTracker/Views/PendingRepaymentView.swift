import SwiftUI

struct RefundsView: View {
    let month: String
    @State private var returnItems: [ReturnItem]
    @State private var loading: Bool
    @State private var sortOrder: SortOrder = .date

    init(month: String) {
        self.month = month
        let cacheKey = "returns_\(month)"
        if let cached: [ReturnItem] = ResponseCache.shared.get(cacheKey) {
            _returnItems = State(initialValue: cached)
            _loading = State(initialValue: false)
        } else {
            _returnItems = State(initialValue: [])
            _loading = State(initialValue: true)
        }
    }

    // Returns metrics
    private var retPending: Double { returnItems.filter { $0.return_status == "pending" }.reduce(0) { $0 + abs($1.amount) } }
    private var retReceived: Double { returnItems.filter { $0.return_status == "received" || $0.return_status == "closed" }.reduce(0) { $0 + abs($1.amount) } }

    var body: some View {
        VStack(spacing: 0) {
            returnsContent
        }
        .background(Theme.Colors.background)
        .navigationTitle("Refunds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SortToggle(order: $sortOrder)
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Returns content

    private var returnsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    SummaryPill(label: "PENDING", value: retPending, color: Theme.Colors.flowCredits)
                    SummaryPill(label: "RECEIVED", value: retReceived, color: Theme.Colors.success)
                }
                .padding(.horizontal)

                if returnItems.isEmpty {
                    Text("No returns")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(.top, 40)
                } else {
                    let retSortFn: (ReturnItem, ReturnItem) -> Bool = sortOrder == .date
                        ? { $0.date > $1.date }
                        : { abs($0.amount) > abs($1.amount) }
                    let pending = returnItems.filter { $0.return_status != "received" && $0.return_status != "closed" }.sorted(by: retSortFn)
                    let completed = returnItems.filter { $0.return_status == "received" || $0.return_status == "closed" }.sorted(by: retSortFn)

                    if !pending.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(pending) { item in
                                retRow(item, grayed: false)
                                if item.id != pending.last?.id {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                    }

                    if !completed.isEmpty {
                        HStack {
                            Text("Completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.textMuted)
                            Rectangle()
                                .fill(Theme.Colors.border)
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        VStack(spacing: 0) {
                            ForEach(completed) { item in
                                retRow(item, grayed: true)
                                if item.id != completed.last?.id {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                        .opacity(0.5)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Row Helper

    private func retRow(_ item: ReturnItem, grayed: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description ?? "Return")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(grayed ? Theme.Colors.textMuted : Theme.Colors.text)
                HStack(spacing: 6) {
                    Text(Formatters.shortDate(item.date))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                    StatusBadge.forReturn(item.return_status ?? "none")
                }
            }
            Spacer()
            Text(Formatters.currency(abs(item.amount), decimals: false))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(grayed ? Color(hex: "#bbb") : Theme.Colors.text)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Data

    func loadData() {
        let cacheKey = "returns_\(month)"
        if returnItems.isEmpty, let cached: [ReturnItem] = ResponseCache.shared.get(cacheKey) {
            returnItems = cached
            loading = false
        }
        Task {
            do {
                let fresh: [ReturnItem] = try await APIClient.shared.request("/api/dashboard/returns?month=\(month)")
                returnItems = fresh
                ResponseCache.shared.set(cacheKey, value: fresh)
            } catch {
                print("Returns load error:", error)
            }
            loading = false
        }
    }
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(Formatters.currency(value, decimals: false))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))
    }
}

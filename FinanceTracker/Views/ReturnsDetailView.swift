import SwiftUI

struct ReturnsDetailView: View {
    let month: String
    @State private var items: [ReturnItem]
    @State private var loading: Bool
    @State private var sortOrder: SortOrder = .date
    @State private var closeConfirmItem: ReturnItem? = nil

    init(month: String) {
        self.month = month
        let cacheKey = "returns_\(month)"
        if let cached: [ReturnItem] = ResponseCache.shared.get(cacheKey) {
            _items = State(initialValue: cached)
            _loading = State(initialValue: false)
        } else {
            _items = State(initialValue: [])
            _loading = State(initialValue: true)
        }
    }

    private var totalPending: Double {
        items.filter { $0.return_status == "pending" || $0.return_status == "partial" }
            .reduce(0) { $0 + abs($1.amount) - ($1.returned_amount ?? 0) }
    }
    private var totalReceived: Double {
        items.filter { $0.return_status == "received" || $0.return_status == "closed" }
            .reduce(0) { $0 + ($1.returned_amount ?? 0) }
    }

    private var sortFn: (ReturnItem, ReturnItem) -> Bool {
        sortOrder == .date
            ? { $0.date > $1.date }
            : { abs($0.amount) > abs($1.amount) }
    }

    private var pendingItems: [ReturnItem] {
        items.filter { $0.return_status != "received" && $0.return_status != "closed" }.sorted(by: sortFn)
    }
    private var completedItems: [ReturnItem] {
        items.filter { $0.return_status == "received" || $0.return_status == "closed" }.sorted(by: sortFn)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(Formatters.currency(totalPending, decimals: false))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.warning)
                        Text("Pending")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))

                    VStack(spacing: 4) {
                        Text(Formatters.currency(totalReceived, decimals: false))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.success)
                        Text("Received")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))
                }
                .padding(.horizontal)

                // Items
                if loading && items.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if items.isEmpty {
                    Text("No returns")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(.top, 40)
                } else {
                    if !pendingItems.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(pendingItems) { item in
                                returnRow(item, grayed: false)
                                if item.id != pendingItems.last?.id {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                    }

                    if !completedItems.isEmpty {
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
                            ForEach(completedItems) { item in
                                returnRow(item, grayed: true)
                                if item.id != completedItems.last?.id {
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
        .background(Theme.Colors.background)
        .navigationTitle("Returns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SortToggle(order: $sortOrder)
            }
        }
        .onAppear { loadData() }
        .alert("Close Return", isPresented: Binding(
            get: { closeConfirmItem != nil },
            set: { if !$0 { closeConfirmItem = nil } }
        )) {
            Button("Close", role: .destructive) {
                if let item = closeConfirmItem {
                    closeShortfall(item)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let item = closeConfirmItem {
                let returned = item.returned_amount ?? 0
                let shortfall = abs(item.amount) - returned
                Text("The unreturned \(Formatters.currency(shortfall, decimals: false)) will be absorbed as spending.")
            }
        }
    }

    private func returnRow(_ item: ReturnItem, grayed: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description ?? "Return")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(grayed ? Theme.Colors.textMuted : Theme.Colors.text)
                HStack(spacing: 6) {
                    Text(Formatters.shortDate(item.date))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                    if let status = item.return_status, status != "none" {
                        if status == "partial" {
                            let returned = item.returned_amount ?? 0
                            StatusBadge(text: "\(Formatters.currency(returned, decimals: false)) back", textColor: Theme.Colors.success, bgColor: Theme.Colors.successBg)
                        } else if status == "closed" {
                            StatusBadge(text: "Closed", textColor: Theme.Colors.textMuted, bgColor: Theme.Colors.divider)
                        } else {
                            StatusBadge.forReturn(status)
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formatters.currency(abs(item.amount), decimals: false))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(grayed ? Color(hex: "#bbb") : Theme.Colors.error)
                // Show shortfall for closed items
                if item.return_status == "closed", let shortfall = item.shortfall_amount, shortfall > 0 {
                    Text("\(Formatters.currency(shortfall, decimals: false)) absorbed")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            if item.return_status == "partial" || item.return_status == "pending" {
                Button {
                    closeConfirmItem = item
                } label: {
                    Label("Close — absorb shortfall", systemImage: "xmark.circle")
                }
            }
        }
    }

    // MARK: - Actions

    func closeShortfall(_ item: ReturnItem) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions/close-shortfall",
                    method: "POST",
                    body: ["transaction_id": item.id, "type": "return"]
                )
                loadData()
            } catch {
                print("Close shortfall error:", error)
            }
        }
    }

    func loadData() {
        let cacheKey = "returns_\(month)"
        if items.isEmpty, let cached: [ReturnItem] = ResponseCache.shared.get(cacheKey) {
            items = cached
            loading = false
        }
        Task {
            do {
                let fresh: [ReturnItem] = try await APIClient.shared.request("/api/dashboard/returns?month=\(month)")
                items = fresh
                ResponseCache.shared.set(cacheKey, value: fresh)
            } catch {
                print("Returns load error:", error)
            }
            loading = false
        }
    }
}

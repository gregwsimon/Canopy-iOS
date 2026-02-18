import SwiftUI

struct ReturnsDetailView: View {
    let month: String
    @State private var items: [ReturnItem] = []
    @State private var loading = true
    @State private var sortOrder: SortOrder = .date

    private var totalPending: Double {
        items.filter { $0.return_status == "pending" }.reduce(0) { $0 + abs($1.amount) }
    }
    private var totalReceived: Double {
        items.filter { $0.return_status == "received" }.reduce(0) { $0 + abs($1.amount) }
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
                        Text("PENDING")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))

                    VStack(spacing: 4) {
                        Text(Formatters.currency(totalReceived, decimals: false))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Colors.success)
                        Text("RECEIVED")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Theme.Colors.textMuted)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.Colors.border, lineWidth: 1))
                }
                .padding(.horizontal)

                // Items
                if loading {
                    ProgressView()
                        .padding(.top, 40)
                } else if items.isEmpty {
                    Text("No returns")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(.top, 40)
                } else {
                    let sortFn: (ReturnItem, ReturnItem) -> Bool = sortOrder == .date
                        ? { $0.date > $1.date }
                        : { abs($0.amount) > abs($1.amount) }
                    let pending = items.filter { $0.return_status != "received" }.sorted(by: sortFn)
                    let completed = items.filter { $0.return_status == "received" }.sorted(by: sortFn)

                    if !pending.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(pending) { item in
                                returnRow(item, grayed: false)
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
                                returnRow(item, grayed: true)
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
        .background(Theme.Colors.background)
        .navigationTitle("Returns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SortToggle(order: $sortOrder)
            }
        }
        .onAppear { loadData() }
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
                    StatusBadge.forReturn(item.return_status ?? "none")
                }
            }
            Spacer()
            Text(Formatters.currency(abs(item.amount), decimals: false))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(grayed ? Color(hex: "#bbb") : Theme.Colors.error)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    func loadData() {
        Task {
            do {
                items = try await APIClient.shared.request("/api/dashboard/returns?month=\(month)")
            } catch {
                print("Returns load error:", error)
            }
            loading = false
        }
    }
}

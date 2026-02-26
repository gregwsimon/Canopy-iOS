import SwiftUI

struct HealthcareDetailView: View {
    let month: String
    @State private var items: [HealthcareItem]
    @State private var loading: Bool
    @State private var sortOrder: SortOrder = .date

    init(month: String) {
        self.month = month
        let cacheKey = "healthcare_\(month)"
        if let cached: [HealthcareItem] = ResponseCache.shared.get(cacheKey) {
            _items = State(initialValue: cached)
            _loading = State(initialValue: false)
        } else {
            _items = State(initialValue: [])
            _loading = State(initialValue: true)
        }
    }

    // MARK: - Metrics (using reimbursed_amount for accuracy)

    /// Total healthcare charges (everything billed)
    private var totalCharged: Double {
        items.reduce(0) { $0 + abs($1.amount) }
    }

    /// Total reimbursed across all partial + complete items
    private var totalReimbursed: Double {
        items.reduce(0) { $0 + ($1.reimbursed_amount ?? 0) }
    }

    /// Out of pocket = true cost after reimbursements (what shows in flexible spend)
    private var outOfPocket: Double {
        totalCharged - totalReimbursed
    }

    /// Awaiting: for pending items full amount, for partial items the unreimbursed remainder
    private var totalAwaiting: Double {
        items.filter { $0.reimbursement_status == "pending" || $0.reimbursement_status == "partial" }
            .reduce(0) { $0 + abs($1.amount) - ($1.reimbursed_amount ?? 0) }
    }

    /// Not submitted for reimbursement at all
    private var totalNotSubmitted: Double {
        items.filter { ($0.reimbursement_status ?? "none") == "none" }
            .reduce(0) { $0 + abs($1.amount) }
    }

    // MARK: - Filtered Lists

    private var sortFn: (HealthcareItem, HealthcareItem) -> Bool {
        sortOrder == .date
            ? { $0.date > $1.date }
            : { abs($0.amount) > abs($1.amount) }
    }

    private var awaitingItems: [HealthcareItem] {
        items.filter { $0.reimbursement_status == "pending" || $0.reimbursement_status == "partial" }.sorted(by: sortFn)
    }
    private var notSubmittedItems: [HealthcareItem] {
        items.filter { ($0.reimbursement_status ?? "none") == "none" }.sorted(by: sortFn)
    }
    private var completedItems: [HealthcareItem] {
        items.filter { $0.reimbursement_status == "complete" }.sorted(by: sortFn)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Summary
            VStack(spacing: 8) {
                // Hero: Out of Pocket
                HStack {
                    Text("Out of pocket")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(Formatters.currency(outOfPocket, decimals: false))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.text)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )

                // Row 1: Total Charged | Awaiting
                HStack(spacing: 8) {
                    SummaryPill(label: "TOTAL CHARGED", value: totalCharged, color: Theme.Colors.text)
                    SummaryPill(label: "AWAITING", value: totalAwaiting, color: Theme.Colors.flowCredits)
                }

                // Row 2: Reimbursed | Not Submitted
                HStack(spacing: 8) {
                    SummaryPill(label: "REIMBURSED", value: totalReimbursed, color: Theme.Colors.success)
                    SummaryPill(label: "NOT SUBMITTED", value: totalNotSubmitted, color: Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Group {
                if loading && items.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    Text("No healthcare expenses")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                } else {
                    List {
                    // Awaiting Reimbursement section (pending + partial)
                    if !awaitingItems.isEmpty {
                        Section {
                            ForEach(awaitingItems) { item in
                                healthcareRow(item)
                                    .swipeActions(edge: .trailing) {
                                        Button("Received") { updateStatus(item, to: "complete") }
                                            .tint(Theme.Colors.success)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button("Cancel") { updateStatus(item, to: "none") }
                                            .tint(Theme.Colors.textSecondary)
                                    }
                            }
                        } header: {
                            Text("Awaiting Reimbursement")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.flowCredits)
                                .textCase(nil)
                                .listRowInsets(EdgeInsets())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.background)
                        }
                    }

                    // Not Submitted section
                    if !notSubmittedItems.isEmpty {
                        Section {
                            ForEach(notSubmittedItems) { item in
                                healthcareRow(item)
                                    .swipeActions(edge: .trailing) {
                                        Button("Submit") { updateStatus(item, to: "pending") }
                                            .tint(Theme.Colors.textSecondary)
                                    }
                            }
                        } header: {
                            Text("Not Submitted")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.textMuted)
                                .textCase(nil)
                                .listRowInsets(EdgeInsets())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.background)
                        }
                    }

                    // Reimbursement Complete section
                    if !completedItems.isEmpty {
                        Section {
                            ForEach(completedItems) { item in
                                healthcareRow(item)
                                    .swipeActions(edge: .trailing) {
                                        Button("Reopen") { updateStatus(item, to: "pending") }
                                            .tint(Theme.Colors.textSecondary)
                                    }
                            }
                        } header: {
                            Text("Reimbursement Complete")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.Colors.success)
                                .textCase(nil)
                                .listRowInsets(EdgeInsets())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.background)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSeparator(.hidden)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Healthcare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SortToggle(order: $sortOrder)
            }
        }
        .onAppear { loadData() }
    }

    // MARK: - Row

    private func healthcareRow(_ item: HealthcareItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description ?? "Healthcare")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                HStack(spacing: 6) {
                    Text(Formatters.shortDate(item.date))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                    if let status = item.reimbursement_status, status != "none" {
                        if status == "partial" || status == "complete" {
                            let reimbursed = item.reimbursed_amount ?? 0
                            if reimbursed > 0 {
                                StatusBadge(text: "\(Formatters.currency(reimbursed, decimals: false)) back", textColor: Theme.Colors.success, bgColor: Theme.Colors.successBg)
                            }
                        } else if status == "pending" {
                            StatusBadge(text: "Submitted", textColor: Theme.Colors.flowCredits, bgColor: Theme.Colors.flowCredits.opacity(0.12))
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Formatters.currency(abs(item.amount), decimals: false))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.Colors.text)
                // Show out-of-pocket for items with reimbursement
                if let reimbursed = item.reimbursed_amount, reimbursed > 0 {
                    let oop = abs(item.amount) - reimbursed
                    if item.reimbursement_status == "complete" {
                        Text("\(Formatters.currency(oop, decimals: false)) out of pocket")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                    } else if item.reimbursement_status == "partial" {
                        Text("\(Formatters.currency(oop, decimals: false)) remaining")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    func updateStatus(_ item: HealthcareItem, to status: String) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": item.id, "reimbursement_status": status]
                )
                loadData()
            } catch {
                print("Update healthcare status error:", error)
            }
        }
    }

    func loadData() {
        let cacheKey = "healthcare_\(month)"
        if items.isEmpty, let cached: [HealthcareItem] = ResponseCache.shared.get(cacheKey) {
            items = cached
            loading = false
        }
        Task {
            do {
                let fresh: [HealthcareItem] = try await APIClient.shared.request("/api/dashboard/healthcare?month=\(month)")
                items = fresh
                ResponseCache.shared.set(cacheKey, value: fresh)
            } catch {
                print("Healthcare load error:", error)
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
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

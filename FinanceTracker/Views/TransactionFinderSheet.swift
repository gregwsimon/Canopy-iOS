import SwiftUI

struct TransactionFinderSheet: View {
    let type: String  // "return" or "healthcare"
    let creditAmount: Double
    let categories: [Category]
    let credit: CreditItem
    let onAllocated: (SearchTransaction, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCategoryId: Int? = nil
    @State private var days = 90
    @State private var tagged: [SearchTransaction] = []
    @State private var suggested: SearchTransaction? = nil
    @State private var results: [SearchTransaction] = []
    @State private var loading = true
    @State private var hasMore = true
    @State private var toastError: String? = nil

    // Nested amount sheet state
    @State private var selectedTx: SearchTransaction? = nil

    private var title: String {
        type == "healthcare" ? "Find Healthcare Expense" : "Find Original Purchase"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.textMuted)
                        .font(.system(size: 14))
                    TextField("Search transactions...", text: $searchText)
                        .font(.system(size: 14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { oldValue, newValue in
                            debounceSearch()
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            loadData()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.textMuted)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radii.card)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 8)

                // Category filter chips (hide for healthcare — API already filters to is_healthcare=true)
                if !categories.isEmpty && type != "healthcare" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            categoryChip(name: "All", id: nil)
                            ForEach(parentCategories) { cat in
                                categoryChip(name: cat.name, id: cat.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // Context bar
                HStack {
                    Text("Credit: +\(Formatters.currency(creditAmount))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.success)
                    Spacer()
                    Text("Last \(days) days")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Theme.Colors.divider)

                // Transaction list
                if loading && tagged.isEmpty && results.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if tagged.isEmpty && suggested == nil && results.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No matching transactions")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Try a different search or load older transactions")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Best match suggestion
                            if let match = suggested {
                                sectionHeader(
                                    "Best Match",
                                    icon: "star.fill",
                                    color: Theme.Colors.success
                                )
                                Button { selectedTx = match } label: {
                                    transactionRow(match, highlighted: true)
                                }
                                Divider().padding(.horizontal)
                            }

                            // Tagged pending items
                            if !tagged.isEmpty {
                                sectionHeader(
                                    type == "healthcare" ? "Pending Reimbursements" : "Pending Refunds",
                                    icon: "tag.fill",
                                    color: type == "healthcare" ? Theme.Colors.flowCredits : Theme.Colors.flowPayoff
                                )
                                ForEach(tagged) { tx in
                                    Button { selectedTx = tx } label: {
                                        transactionRow(tx)
                                    }
                                    if tx.id != tagged.last?.id {
                                        Divider().padding(.horizontal)
                                    }
                                }
                                if !results.isEmpty {
                                    Divider().padding(.horizontal)
                                }
                            }

                            // General results
                            if !results.isEmpty {
                                sectionHeader(
                                    "All Transactions",
                                    icon: "list.bullet",
                                    color: Theme.Colors.textMuted
                                )
                                ForEach(results) { tx in
                                    Button { selectedTx = tx } label: {
                                        transactionRow(tx)
                                    }
                                    if tx.id != results.last?.id {
                                        Divider().padding(.horizontal)
                                    }
                                }
                            }

                            // Load older button
                            if hasMore {
                                Button {
                                    extendDateRange()
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 12))
                                        Text("Load older transactions")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(Theme.Colors.flowFlex)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }
                                .disabled(loading)
                            }
                        }
                    }
                }
            }
            .background(Theme.Colors.background)
            .toastError($toastError)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .onAppear { loadData() }
            .sheet(item: $selectedTx) { tx in
                AllocationAmountSheet(
                    credit: credit,
                    action: type == "healthcare" ? "healthcare" : "return",
                    targetTransaction: tx,
                    targetCategory: nil,
                    targetGoal: nil,
                    onAllocate: { amount in
                        onAllocated(tx, amount)
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Category Chips

    private var parentCategories: [Category] {
        // Show only parent categories (no parent_id) for cleaner filter
        let parents = categories.filter { $0.parent_id == nil }
        return parents.isEmpty ? categories : parents
    }

    private func categoryChip(name: String, id: Int?) -> some View {
        let isSelected = selectedCategoryId == id
        return Button {
            selectedCategoryId = id
            loadData()
        } label: {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.Colors.text : Theme.Colors.surface)
                .cornerRadius(Theme.Radii.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radii.pill)
                        .stroke(Theme.Colors.border, lineWidth: isSelected ? 0 : 1)
                )
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Theme.Colors.background)
    }

    // MARK: - Transaction Row

    private func transactionRow(_ tx: SearchTransaction, highlighted: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.description ?? "Transaction")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Formatters.shortDate(tx.date))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMuted)
                    if let catName = tx.categoryName {
                        Text(catName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.subtleBg)
                            .cornerRadius(Theme.Radii.badge)
                    }
                    if type == "return" && tx.isReturn == true {
                        statusPill("Return", color: Theme.Colors.flowPayoff)
                    }
                    if type == "healthcare" && tx.isHealthcare == true {
                        statusPill("HC", color: Theme.Colors.flowCredits)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.currency(abs(tx.amount)))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.Colors.text)
                if let remaining = tx.remainingAmount, remaining < abs(tx.amount) {
                    Text("\(Formatters.currency(remaining)) left")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.flowCredits)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textDisabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(highlighted ? Theme.Colors.success.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }

    private func statusPill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .cornerRadius(Theme.Radii.badge)
    }

    // MARK: - Data

    @State private var searchTask: Task<Void, Never>?

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            if !Task.isCancelled {
                await MainActor.run { loadData() }
            }
        }
    }

    private func loadData() {
        loading = true
        Task {
            do {
                var params = "type=\(type)&days=\(days)&limit=50"
                if !searchText.isEmpty {
                    let encoded = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
                    params += "&q=\(encoded)"
                }
                if let catId = selectedCategoryId {
                    params += "&category_id=\(catId)"
                }
                // Pass credit info for smart matching
                if let desc = credit.description {
                    let encoded = desc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? desc
                    params += "&credit_description=\(encoded)"
                }
                params += "&credit_amount=\(credit.remainingAmount ?? credit.amount)"

                let response: TransactionSearchResponse = try await APIClient.shared.request("/api/transactions/search?\(params)")
                tagged = response.tagged.filter { !isFullyMatched($0) }
                suggested = response.suggested.flatMap { isFullyMatched($0) ? nil : $0 }
                results = response.results.filter { !isFullyMatched($0) }
            } catch {
                toastError = "Failed to search transactions"
            }
            loading = false
        }
    }

    private func isFullyMatched(_ tx: SearchTransaction) -> Bool {
        if let remaining = tx.remainingAmount, remaining <= 0 { return true }
        if type == "return" && tx.returnStatus == "received" && tx.remainingAmount == nil { return true }
        if type == "healthcare" && tx.reimbursementStatus == "complete" && tx.remainingAmount == nil { return true }
        return false
    }

    private func extendDateRange() {
        if days == 90 { days = 180 }
        else if days == 180 { days = 365 }
        else if days == 365 { days = 730 }
        else { hasMore = false; return }
        loadData()
    }
}

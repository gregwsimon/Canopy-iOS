import SwiftUI

struct CategoryTransactionsSheet: View {
    let categoryName: String
    let categoryId: Int
    let month: String
    var fixedFilter: Bool? = nil   // true = only fixed, false = only non-fixed, nil = all
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [Transaction] = []
    @State private var loading = true
    @State private var recategorizeTxn: Transaction?
    @State private var editingTransaction: Transaction?
    @State private var selectedSubCategory: String? = nil
    @State private var sortOrder: SortOrder = .amount

    private var subCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for txn in filteredByFixed {
            let name = txn.category_name ?? ""
            if !name.isEmpty && name != categoryName && seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result.sorted()
    }

    private var filteredByFixed: [Transaction] {
        guard let filter = fixedFilter else { return transactions }
        return transactions.filter { ($0.is_fixed ?? false) == filter }
    }

    private var displayedTransactions: [Transaction] {
        var result: [Transaction]
        if let sub = selectedSubCategory {
            result = filteredByFixed.filter { $0.category_name == sub }
        } else {
            result = filteredByFixed
        }
        switch sortOrder {
        case .date:
            result.sort { ($0.date) > ($1.date) }
        case .amount:
            result.sort { abs($0.amount) > abs($1.amount) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sub-category filter pills
                if subCategories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            subCategoryPill(name: "All", value: nil)
                            ForEach(subCategories, id: \.self) { sub in
                                subCategoryPill(name: sub, value: sub)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Theme.Colors.background)
                }

            List {
                ForEach(displayedTransactions) { txn in
                    let isCompleted = txn.return_status == "received" || txn.reimbursement_status == "complete"
                    let isUnallocatedCredit = txn.credit_allocation == "unallocated"
                    let isGreyed = isCompleted || isUnallocatedCredit
                    Button { editingTransaction = txn } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(txn.description ?? "—")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: isGreyed ? "#999" : "#171717"))
                                HStack(spacing: 4) {
                                    Text(txn.category_name ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    if txn.is_fixed == true {
                                        StatusBadge(text: "Fixed", textColor: Theme.Colors.textSecondary, bgColor: Color(hex: "#e5e5e5"))
                                    }
                                    if txn.is_return == true {
                                        StatusBadge.forReturn(txn.return_status ?? "pending")
                                    }
                                    if txn.is_healthcare == true, let rs = txn.reimbursement_status, rs != "none" {
                                        if rs == "partial" {
                                            StatusBadge(text: "Partial", textColor: Theme.Colors.flowCredits, bgColor: Theme.Colors.flowCredits.opacity(0.12))
                                            StatusBadge(text: "Reimbursed", textColor: Theme.Colors.success, bgColor: Theme.Colors.successBg)
                                        } else {
                                            StatusBadge.forHealthcare(rs)
                                        }
                                    }
                                    if txn.is_amortized == true, let months = txn.amortize_months {
                                        StatusBadge(text: "\(months)mo", textColor: Theme.Colors.accent, bgColor: Theme.Colors.accentBg)
                                    }
                                    if isUnallocatedCredit {
                                        StatusBadge(text: "Credit", textColor: Theme.Colors.success, bgColor: Color(hex: "#dcfce7"))
                                    }
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatters.currency(txn.amount))
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(isGreyed ? Color(hex: "#bbb") : (txn.amount >= 0 ? Theme.Colors.success : Theme.Colors.error))
                                Text(Formatters.shortDate(txn.date))
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textMuted)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textDisabled)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteTransaction(txn.id)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { recategorizeTxn = txn } label: {
                            Image(systemName: "folder")
                        }
                        .tint(.blue)

                        if txn.category_type == "expense" {
                            Button { toggleFixed(txn) } label: {
                                Image(systemName: txn.is_fixed == true ? "pin.slash" : "pin")
                            }
                            .tint(Theme.Colors.flowFixed)

                            if txn.is_return == true {
                                Button { undoReturn(txn) } label: {
                                    Image(systemName: "arrow.uturn.right")
                                }
                                .tint(Theme.Colors.flowCredits)
                            } else {
                                Button { toggleReturn(txn) } label: {
                                    Image(systemName: "arrow.uturn.left")
                                }
                                .tint(Theme.Colors.flowCredits)
                            }
                        }

                        if txn.amount > 0 && (txn.credit_allocation == nil || txn.credit_allocation == "none") {
                            Button { markAsCredit(txn) } label: {
                                Image(systemName: "dollarsign.circle")
                            }
                            .tint(Theme.Colors.flowCredits)
                        }
                    }
                    .listRowBackground(Theme.Colors.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                }

                if !displayedTransactions.isEmpty {
                    // Total row (exclude unallocated credits, matching sankey)
                    HStack {
                        Text("Total")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        let total = displayedTransactions
                            .filter { $0.credit_allocation != "unallocated" }
                            .reduce(0.0) { $0 + $1.amount }
                        Text(Formatters.currency(abs(total)))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(total >= 0 ? Theme.Colors.success : Theme.Colors.error)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .listRowBackground(Theme.Colors.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.background)
                } else if displayedTransactions.isEmpty {
                    Text("No transactions found")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            }
            .background(Theme.Colors.background)
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SortToggle(order: $sortOrder)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .sheet(item: $recategorizeTxn) { txn in
                GroupedCategoryPicker(
                    title: "Move to Category",
                    currentCategoryId: txn.category_id,
                    onSelect: { id, _ in
                        recategorize(txn, to: id)
                    }
                )
            }
            .sheet(item: $editingTransaction) { txn in
                TransactionEditSheet(transaction: txn) {
                    loadTransactions()
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { loadTransactions() }
    }

    private func loadTransactions() {
        loading = true
        Task {
            do {
                let all: [Transaction] = try await APIClient.shared.request(
                    "/api/transactions?month=\(month)&category_id=\(categoryId)"
                )
                transactions = all
            } catch {
                print("CategoryTransactions load error:", error)
            }
            loading = false
        }
    }

    private func toggleFixed(_ txn: Transaction) {
        let newValue = !(txn.is_fixed ?? false)
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "is_fixed": newValue]
                )
                loadTransactions()
            } catch {
                print("Toggle fixed error:", error)
            }
        }
    }

    private func toggleReturn(_ txn: Transaction) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "is_return": true, "return_status": "pending"]
                )
                loadTransactions()
            } catch {
                print("Toggle return error:", error)
            }
        }
    }

    private func undoReturn(_ txn: Transaction) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "is_return": false, "return_status": "none"]
                )
                loadTransactions()
            } catch {
                print("Undo return error:", error)
            }
        }
    }

    private func markAsCredit(_ txn: Transaction) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/credits/reset",
                    method: "POST",
                    body: ["transaction_id": txn.id]
                )
                loadTransactions()
            } catch {
                print("Mark as credit error:", error)
            }
        }
    }

    private func deleteTransaction(_ id: Int) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request("/api/transactions?id=\(id)", method: "DELETE")
                loadTransactions()
            } catch {
                print("Delete error:", error)
            }
        }
    }

    private func recategorize(_ txn: Transaction, to newCatId: Int) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "category_id": newCatId]
                )
                loadTransactions()
            } catch {
                print("Recategorize error:", error)
            }
        }
    }

    private func subCategoryPill(name: String, value: String?) -> some View {
        let isSelected = selectedSubCategory == value
        return Button {
            selectedSubCategory = value
        } label: {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.Colors.text : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Colors.border, lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

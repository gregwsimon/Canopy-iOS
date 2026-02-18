import SwiftUI

struct TransactionsView: View {
    @State private var month = DashboardView.currentMonth()
    @State private var transactions: [Transaction] = []
    @State private var loading = true
    @State private var showAdd = false
    @State private var syncing = false
    @State private var syncMessage = ""
    @State private var editingTransaction: Transaction?
    @State private var recategorizeTxn: Transaction?
    @State private var accountFilter: AccountFilter = .all
    @State private var searchText = ""
    @State private var selectedCategoryFilter: String? = nil
    @State private var sortOrder: SortOrder = .date

    enum AccountFilter: String, CaseIterable {
        case all = "All"
        case checking = "Checking"
        case credit = "Credit Card"
    }

    private var categoryFilters: [String] {
        // Derive unique parent category names from transactions
        var seen = Set<String>()
        var result: [String] = []
        for txn in transactions {
            let name = txn.parent_category_name ?? txn.category_name ?? ""
            if !name.isEmpty && seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result.sorted()
    }

    private var categoryColorMap: [String: String] {
        var map: [String: String] = [:]
        for txn in transactions {
            let name = txn.parent_category_name ?? txn.category_name ?? ""
            if !name.isEmpty && map[name] == nil, let color = txn.category_color {
                map[name] = color
            }
        }
        return map
    }

    private var filteredTransactions: [Transaction] {
        var result: [Transaction]
        switch accountFilter {
        case .all: result = transactions
        case .checking: result = transactions.filter { $0.account_type == "checking" }
        case .credit: result = transactions.filter { $0.account_type == "credit" }
        }
        if let catFilter = selectedCategoryFilter {
            result = result.filter { txn in
                txn.parent_category_name == catFilter || txn.category_name == catFilter
            }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { txn in
                (txn.description?.lowercased().contains(query) ?? false) ||
                (txn.category_name?.lowercased().contains(query) ?? false)
            }
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
                // Controls
                HStack {
                    Button(action: { adjustMonth(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    Text(Formatters.monthLabel(month))
                        .font(.system(size: 14, weight: .medium))
                    Button(action: { adjustMonth(1) }) {
                        Image(systemName: "chevron.right")
                    }

                    Spacer()

                    Button(syncing ? "Syncing..." : "Sync") {
                        syncFromBank()
                    }
                    .disabled(syncing)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )

                    SortToggle(order: $sortOrder)
                }
                .padding()

                // Account filter
                Picker("Account", selection: $accountFilter) {
                    ForEach(AccountFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.textMuted)
                        .font(.system(size: 13))
                    TextField("Search transactions...", text: $searchText)
                        .font(.system(size: 14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.textMuted)
                                .font(.system(size: 13))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 6)

                // Category filter pills
                if !categoryFilters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            categoryPill(name: "All", value: nil, color: "#171717")
                            ForEach(categoryFilters, id: \.self) { cat in
                                categoryPill(name: cat, value: cat, color: categoryColorMap[cat] ?? "#171717")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 6)
                }

                if !syncMessage.isEmpty {
                    Text(syncMessage)
                        .font(.system(size: 12))
                        .foregroundColor(syncMessage.contains("failed") ? Theme.Colors.error : Theme.Colors.accent)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredTransactions.isEmpty {
                    Spacer()
                    Text("No transactions for this month")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTransactions) { txn in
                            let isCompleted = txn.return_status == "received" || txn.reimbursement_status == "complete"
                            Button { editingTransaction = txn } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(txn.description ?? "—")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: isCompleted ? "#999" : "#171717"))
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
                                            if txn.is_healthcare == true, let hcStatus = txn.reimbursement_status, hcStatus != "none" {
                                                if hcStatus == "partial" {
                                                    StatusBadge(text: "Partial", textColor: Theme.Colors.warning, bgColor: Theme.Colors.warningBg)
                                                    StatusBadge(text: "Reimbursed", textColor: Theme.Colors.success, bgColor: Theme.Colors.successBg)
                                                } else {
                                                    StatusBadge.forHealthcare(hcStatus)
                                                }
                                            }
                                            if txn.is_amortized == true, let months = txn.amortize_months {
                                                StatusBadge(text: "\(months)mo", textColor: Theme.Colors.accent, bgColor: Theme.Colors.accentBg)
                                            }
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(Formatters.currency(txn.amount))
                                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                            .foregroundColor(isCompleted ? Color(hex: "#bbb") : (txn.amount >= 0 ? Theme.Colors.success : Theme.Colors.error))
                                        Text(Formatters.shortDate(txn.date))
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.Colors.textMuted)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textDisabled)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    deleteTransaction(txn.id)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button { recategorizeTxn = txn } label: {
                                    Image(systemName: "folder")
                                }
                                .tint(Theme.Colors.accent)

                                if txn.category_type == "expense" {
                                    Button { toggleFixed(txn) } label: {
                                        Image(systemName: txn.is_fixed == true ? "pin.slash" : "pin")
                                    }
                                    .tint(Theme.Colors.textSecondary)

                                    if txn.is_return == true {
                                        Button { undoReturn(txn) } label: {
                                            Image(systemName: "arrow.uturn.right")
                                        }
                                        .tint(Theme.Colors.warning)
                                    } else {
                                        Button { toggleReturn(txn) } label: {
                                            Image(systemName: "arrow.uturn.left")
                                        }
                                        .tint(Theme.Colors.purple)
                                    }
                                }
                            }
                        }

                        // Total
                        HStack {
                            Text("Net Total")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            let total = filteredTransactions.reduce(0) { $0 + $1.amount }
                            Text(Formatters.currency(total))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(total >= 0 ? Theme.Colors.success : Theme.Colors.error)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAdd) {
                AddTransactionView(onSave: { loadData() })
            }
            .sheet(item: $editingTransaction) { txn in
                TransactionEditSheet(transaction: txn) {
                    loadData()
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
        }
        .onAppear { loadData() }
    }

    func adjustMonth(_ delta: Int) {
        let parts = month.split(separator: "-")
        guard parts.count == 2, var m = Int(parts[1]), var y = Int(parts[0]) else { return }
        m += delta
        if m > 12 { m = 1; y += 1 }
        if m < 1 { m = 12; y -= 1 }
        month = "\(y)-\(String(format: "%02d", m))"
        loadData()
    }

    func loadData() {
        loading = true
        Task {
            do {
                transactions = try await APIClient.shared.request("/api/transactions?month=\(month)")
            } catch {
                print("Load error:", error)
            }
            loading = false
        }
    }

    func syncFromBank() {
        syncing = true
        syncMessage = ""
        Task {
            do {
                let result: SyncResult = try await APIClient.shared.request("/api/plaid/sync", method: "POST", body: [:], timeout: 120)
                syncMessage = "Synced \(result.transactions_added) new transactions"
                loadData()
            } catch {
                syncMessage = "Sync failed"
            }
            syncing = false
        }
    }

    func toggleFixed(_ txn: Transaction) {
        let newValue = !(txn.is_fixed ?? false)
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "is_fixed": newValue]
                )
                loadData()
            } catch {
                print("Toggle fixed error:", error)
            }
        }
    }

    func toggleReturn(_ txn: Transaction) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "is_return": true, "return_status": "pending"]
                )
                loadData()
            } catch {
                print("Toggle return error:", error)
            }
        }
    }

    func undoReturn(_ txn: Transaction) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "is_return": false, "return_status": "none"]
                )
                loadData()
            } catch {
                print("Undo return error:", error)
            }
        }
    }

    func recategorize(_ txn: Transaction, to newCatId: Int) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "category_id": newCatId]
                )
                loadData()
            } catch {
                print("Recategorize error:", error)
            }
        }
    }

    func deleteTransaction(_ id: Int) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request("/api/transactions?id=\(id)", method: "DELETE")
                loadData()
            } catch {
                print("Delete error:", error)
            }
        }
    }

    func categoryPill(name: String, value: String?, color: String = "#171717") -> some View {
        let isSelected = selectedCategoryFilter == value
        return Button {
            selectedCategoryFilter = value
        } label: {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : Theme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color(hex: color) : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Colors.border, lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

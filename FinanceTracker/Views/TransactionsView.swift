import SwiftUI

struct TransactionsView: View {
    @State private var month = DashboardView.currentMonth()
    @State private var transactions: [Transaction] = []
    @State private var loading = true
    @State private var showAdd = false
    @State private var syncing = false
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

    private var hasActiveFilter: Bool {
        accountFilter != .all || selectedCategoryFilter != nil
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
                // Row 1: Month picker + filter + sort
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

                    // Filter menu (account + category)
                    Menu {
                        // Account section
                        Section("Account") {
                            ForEach(AccountFilter.allCases, id: \.self) { filter in
                                Button {
                                    accountFilter = filter
                                } label: {
                                    Label(filter.rawValue, systemImage: accountFilter == filter ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        }
                        // Category section
                        if !categoryFilters.isEmpty {
                            Section("Category") {
                                Button {
                                    selectedCategoryFilter = nil
                                } label: {
                                    Label("All Categories", systemImage: selectedCategoryFilter == nil ? "checkmark.circle.fill" : "circle")
                                }
                                ForEach(categoryFilters, id: \.self) { cat in
                                    Button {
                                        selectedCategoryFilter = cat
                                    } label: {
                                        Label(cat, systemImage: selectedCategoryFilter == cat ? "checkmark.circle.fill" : "circle")
                                    }
                                }
                            }
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(hasActiveFilter ? Theme.Colors.accent : Theme.Colors.textSecondary)
                                .frame(width: 32, height: 32)
                            if hasActiveFilter {
                                Circle()
                                    .fill(Theme.Colors.accent)
                                    .frame(width: 6, height: 6)
                                    .offset(x: -4, y: 4)
                            }
                        }
                    }

                    SortToggle(order: $sortOrder)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .fixedSize(horizontal: false, vertical: true)

                // Row 2: Search bar + active filter chip
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.textMuted)
                            .font(.system(size: 12))
                        TextField("Search...", text: $searchText)
                            .font(.system(size: 13))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.textMuted)
                                .font(.system(size: 12))
                        }
                        .opacity(searchText.isEmpty ? 0 : 1)
                        .allowsHitTesting(!searchText.isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Theme.Colors.surfaceSolid)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )

                    // Show active filter as a dismissible chip
                    if let cat = selectedCategoryFilter {
                        Button {
                            selectedCategoryFilter = nil
                        } label: {
                            HStack(spacing: 3) {
                                Text(cat)
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.accent.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
                .fixedSize(horizontal: false, vertical: true)

                if loading && transactions.isEmpty {
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
                                                    StatusBadge(text: "Partial", textColor: Theme.Colors.flowCredits, bgColor: Theme.Colors.flowCredits.opacity(0.12))
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

                                // Mark positive-amount transactions as credit for triage
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
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await syncAndReload()
                    }
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
        let cacheKey = "transactions_\(month)"
        // Show cached data instantly if available
        if transactions.isEmpty, let cached: [Transaction] = ResponseCache.shared.get(cacheKey) {
            transactions = cached
            loading = false
        }
        Task {
            do {
                let fresh: [Transaction] = try await APIClient.shared.request("/api/transactions?month=\(month)")
                transactions = fresh
                ResponseCache.shared.set(cacheKey, value: fresh)
            } catch {
                print("Load error:", error)
            }
            loading = false
        }
    }

    func syncAndReload() async {
        syncing = true
        do {
            let _: SyncResult = try await APIClient.shared.request("/api/plaid/sync", method: "POST", body: [:], timeout: 120)
            loadData()
        } catch {
            print("Sync failed:", error)
        }
        syncing = false
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

    func markAsCredit(_ txn: Transaction) {
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": txn.id, "credit_allocation": "unallocated"]
                )
                loadData()
            } catch {
                print("Mark as credit error:", error)
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

}

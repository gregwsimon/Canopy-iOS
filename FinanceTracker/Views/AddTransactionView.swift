import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void

    @State private var date = Date()
    @State private var amount = ""
    @State private var description = ""
    @State private var selectedCategoryId: Int?
    @State private var selectedAccountId: Int?
    @State private var categories: [Category] = []
    @State private var accounts: [Account] = []
    @State private var saving = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)

                TextField("Description", text: $description)

                Picker("Category", selection: $selectedCategoryId) {
                    Text("Select...").tag(nil as Int?)
                    ForEach(categories) { cat in
                        Text(cat.name).tag(cat.id as Int?)
                    }
                }

                Picker("Account", selection: $selectedAccountId) {
                    Text("Select...").tag(nil as Int?)
                    ForEach(accounts) { acc in
                        Text(acc.name).tag(acc.id as Int?)
                    }
                }

                if !error.isEmpty {
                    Text(error)
                        .foregroundColor(Theme.Colors.error)
                        .font(Theme.Fonts.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving..." : "Save") { save() }
                        .disabled(saving || amount.isEmpty || selectedCategoryId == nil || selectedAccountId == nil)
                }
            }
        }
        .onAppear { loadOptions() }
    }

    func loadOptions() {
        Task {
            do {
                categories = try await APIClient.shared.request("/api/categories")
                accounts = try await APIClient.shared.request("/api/accounts")
            } catch {
                print("Load options error:", error)
            }
        }
    }

    func save() {
        guard let catId = selectedCategoryId, let accId = selectedAccountId else { return }
        guard let amountVal = Double(amount) else {
            error = "Invalid amount"
            return
        }

        let cat = categories.first(where: { $0.id == catId })
        let isExpense = cat?.category_type == "expense" || cat?.category_type == "pretax_deduction"
        let finalAmount = isExpense ? -abs(amountVal) : abs(amountVal)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        saving = true
        Task {
            do {
                let _: InsertResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "POST",
                    body: [
                        "date": dateStr,
                        "amount": finalAmount,
                        "description": description,
                        "category_id": catId,
                        "account_id": accId,
                    ]
                )
                onSave()
                dismiss()
            } catch {
                self.error = error.localizedDescription
                saving = false
            }
        }
    }
}

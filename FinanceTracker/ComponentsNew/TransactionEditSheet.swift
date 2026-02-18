import SwiftUI

struct TransactionEditSheet: View {
    let transaction: Transaction
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var editedDescription: String = ""
    @State private var editedCategoryId: Int? = nil
    @State private var editedCategoryName: String = ""
    @State private var showCategoryPicker = false
    @State private var showAmortizeSheet = false
    @State private var saving = false

    private var hasChanges: Bool {
        let descChanged = editedDescription != (transaction.description ?? "")
        let catChanged = editedCategoryId != nil && editedCategoryId != transaction.category_id
        return descChanged || catChanged
    }

    private var isExpense: Bool {
        transaction.category_type == "expense" && transaction.amount < 0
    }

    private var canSpread: Bool {
        isExpense &&
        transaction.is_amortized != true &&
        transaction.is_return != true
    }

    var body: some View {
        NavigationStack {
            List {
                // Editable fields
                Section {
                    HStack {
                        Text("Name")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("Description", text: $editedDescription)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.trailing)
                    }

                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            Text("Category")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            Text(editedCategoryName)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.text)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textDisabled)
                        }
                    }
                }

                // Read-only fields
                Section {
                    readOnlyRow("Date", Formatters.shortDate(transaction.date))
                    readOnlyRow("Amount", Formatters.currency(transaction.amount))
                    if let account = transaction.account_name {
                        readOnlyRow("Account", account)
                    }
                    if let createdBy = transaction.created_by_name {
                        readOnlyRow("Created by", createdBy)
                    }
                }

                // Amortization status
                if transaction.is_amortized == true,
                   let months = transaction.amortize_months,
                   let start = transaction.amortize_start {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Paying off over \(months) months")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Theme.Colors.accent)
                                Text("\(Formatters.currency(abs(transaction.amount) / Double(months), decimals: false))/mo · \(Formatters.monthRange(start, months: months))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }

                        Button {
                            unspread()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 12))
                                Text("Un-spread")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Theme.Colors.error)
                        }
                    }
                }

                // Spread action
                if canSpread {
                    Section {
                        Button {
                            showAmortizeSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 13))
                                Text("Payoff Over Time")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.Colors.text)
                        .foregroundColor(.white)
                    }
                }

                // Info note about auto-propagation
                if hasChanges {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.accent)
                            Text("Changes will apply to all matching transactions and future imports")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 14, weight: .semibold))
                        .disabled(!hasChanges || saving)
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                GroupedCategoryPicker(
                    title: "Category",
                    currentCategoryId: editedCategoryId ?? transaction.category_id,
                    onSelect: { id, name in
                        editedCategoryId = id
                        editedCategoryName = name
                    }
                )
            }
            .sheet(isPresented: $showAmortizeSheet) {
                AmortizeSheet(
                    transactionId: transaction.id,
                    transactionAmount: transaction.amount,
                    transactionDescription: transaction.description ?? "",
                    transactionDate: transaction.date,
                    onAmortized: {
                        onSave?()
                        dismiss()
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            editedDescription = transaction.description ?? ""
            editedCategoryId = transaction.category_id
            editedCategoryName = transaction.category_name ?? ""
        }
    }

    private func readOnlyRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.text)
        }
    }

    private func save() {
        saving = true
        Task {
            do {
                // Build PATCH body
                var body: [String: Any] = ["id": transaction.id]
                let descChanged = editedDescription != (transaction.description ?? "")
                let catChanged = editedCategoryId != nil && editedCategoryId != transaction.category_id

                if descChanged { body["description"] = editedDescription }
                if catChanged { body["category_id"] = editedCategoryId! }

                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: body
                )

                onSave?()
                dismiss()
            } catch {
                print("TransactionEdit save error:", error)
            }
            saving = false
        }
    }

    private func unspread() {
        saving = true
        Task {
            do {
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: ["id": transaction.id, "is_amortized": false]
                )
                onSave?()
                dismiss()
            } catch {
                print("Unspread error:", error)
            }
            saving = false
        }
    }

}

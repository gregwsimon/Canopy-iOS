import SwiftUI

struct SpreadEditSheet: View {
    let item: SpreadItem
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonths: Int = 6
    @State private var customMonths: String = ""
    @State private var isCustom = false
    @State private var saving = false

    private let durationOptions = [3, 6, 12]

    private var effectiveMonths: Int {
        isCustom ? max(Int(customMonths) ?? 1, 1) : selectedMonths
    }

    private var absAmount: Double { abs(item.totalAmount) }

    private var monthlyAmount: Double {
        absAmount / Double(max(effectiveMonths, 1))
    }

    private var endMonth: String {
        Formatters.addMonths(item.startMonth, effectiveMonths - 1)
    }

    private var hasChanges: Bool {
        effectiveMonths != item.months && effectiveMonths >= 2
    }

    var body: some View {
        NavigationStack {
            List {
                // Header with transaction info
                Section {
                    VStack(spacing: 4) {
                        Text(Formatters.currency(absAmount))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.rose)
                        Text(item.description)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(item.categoryName)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // Current spread info
                Section {
                    HStack {
                        Text("Duration")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text("\(item.months) months")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.text)
                    }
                    HStack {
                        Text("Monthly")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.currency(item.monthlyPortion, decimals: false) + "/mo")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.text)
                    }
                    HStack {
                        Text("Period")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.monthRange(item.startMonth, months: item.months))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.text)
                    }
                } header: { Text("Current").sectionHeaderStyle() }

                // Duration picker
                Section("Adjust Duration") {
                    HStack(spacing: 8) {
                        ForEach(durationOptions, id: \.self) { n in
                            Button {
                                selectedMonths = n
                                isCustom = false
                            } label: {
                                Text("\(n) mo")
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(!isCustom && selectedMonths == n ? Theme.Colors.text : Color.white)
                                    .foregroundColor(!isCustom && selectedMonths == n ? .white : Theme.Colors.textSecondary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Theme.Colors.border, lineWidth: !isCustom && selectedMonths == n ? 0 : 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            isCustom = true
                        } label: {
                            Text("Custom")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isCustom ? Theme.Colors.text : Color.white)
                                .foregroundColor(isCustom ? .white : Theme.Colors.textSecondary)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Theme.Colors.border, lineWidth: isCustom ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if isCustom {
                        HStack {
                            Text("Months")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            TextField("e.g. 9", text: $customMonths)
                                .font(.system(size: 14))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }
                }

                // Updated preview
                if hasChanges {
                    Section("Updated Preview") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(Formatters.currency(monthlyAmount, decimals: false) + "/mo")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.Colors.rose)
                                Spacer()
                                Text("\(effectiveMonths) months")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            Text("\(Formatters.monthLabel(item.startMonth)) – \(Formatters.monthLabel(endMonth))")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)

                            // Change indicator
                            let diff = monthlyAmount - item.monthlyPortion
                            if abs(diff) > 0.5 {
                                HStack(spacing: 4) {
                                    Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 10))
                                    Text(diff > 0 ? "+\(Formatters.currency(diff, decimals: false))/mo" : "\(Formatters.currency(diff, decimals: false))/mo")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(diff > 0 ? Theme.Colors.error : Theme.Colors.success)
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Save button
                Section {
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            Spacer()
                            if saving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(hasChanges ? Theme.Colors.text : Theme.Colors.textDisabled)
                    .foregroundColor(.white)
                    .disabled(!hasChanges || saving)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Edit Payoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            // Initialize to current months
            let current = item.months
            if durationOptions.contains(current) {
                selectedMonths = current
                isCustom = false
            } else {
                isCustom = true
                customMonths = "\(current)"
            }
        }
    }

    private func saveChanges() {
        guard hasChanges else { return }
        saving = true
        Task {
            do {
                let body: [String: Any] = [
                    "id": item.id,
                    "amortize_months": effectiveMonths
                ]
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: body
                )
                onSaved?()
                dismiss()
            } catch {
                print("SpreadEdit save error:", error)
            }
            saving = false
        }
    }
}

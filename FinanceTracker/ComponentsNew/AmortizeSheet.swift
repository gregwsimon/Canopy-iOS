import SwiftUI

struct AmortizeSheet: View {
    let transactionId: Int
    let transactionAmount: Double
    let transactionDescription: String
    let transactionDate: String
    var onAmortized: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonths: Int = 6
    @State private var customMonths: String = ""
    @State private var isCustom = false
    @State private var startMonth: String = ""
    @State private var trackGoal = false
    @State private var goalName: String = ""
    @State private var saving = false

    private let durationOptions = [3, 6, 12]

    private var effectiveMonths: Int {
        isCustom ? max(Int(customMonths) ?? 1, 1) : selectedMonths
    }

    private var absAmount: Double { abs(transactionAmount) }

    private var monthlyAmount: Double {
        absAmount / Double(max(effectiveMonths, 1))
    }

    private var endMonth: String {
        Formatters.addMonths(startMonth, effectiveMonths - 1)
    }

    var body: some View {
        NavigationStack {
            List {
                // Amount header
                Section {
                    VStack(spacing: 4) {
                        Text(Formatters.currency(absAmount))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.error)
                        Text(transactionDescription.isEmpty ? "Untitled" : transactionDescription)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // Duration picker
                Section("Duration") {
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

                // Start month
                Section("Start month") {
                    HStack {
                        Text("From")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text(Formatters.monthLabel(startMonth))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.text)
                    }
                }

                // Preview
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(Formatters.currency(monthlyAmount, decimals: false) + "/mo")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Colors.text)
                            Spacer()
                            Text("\(effectiveMonths) months")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text("\(Formatters.monthLabel(startMonth)) – \(Formatters.monthLabel(endMonth))")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.vertical, 4)
                }

                // Goal toggle
                Section {
                    Toggle(isOn: $trackGoal) {
                        Text("Track as a goal")
                            .font(.system(size: 14))
                    }
                    .tint(Theme.Colors.text)

                    if trackGoal {
                        HStack {
                            Text("Name")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                            TextField("Goal name", text: $goalName)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                // Confirm button
                Section {
                    Button {
                        confirmAmortize()
                    } label: {
                        HStack {
                            Spacer()
                            if saving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Confirm")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(effectiveMonths >= 2 ? Theme.Colors.text : Theme.Colors.textDisabled)
                    .foregroundColor(.white)
                    .disabled(saving || effectiveMonths < 2)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Payoff Over Time")
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
            startMonth = String(transactionDate.prefix(7))
            goalName = transactionDescription
        }
    }

    private func confirmAmortize() {
        guard effectiveMonths >= 2 else { return }
        saving = true
        Task {
            do {
                var body: [String: Any] = [
                    "id": transactionId,
                    "is_amortized": true,
                    "amortize_months": effectiveMonths,
                    "amortize_start": startMonth
                ]
                if trackGoal {
                    body["createGoal"] = true
                    body["goalName"] = goalName.isEmpty ? transactionDescription : goalName
                    body["goalAmount"] = absAmount
                }
                let _: OkResult = try await APIClient.shared.request(
                    "/api/transactions",
                    method: "PATCH",
                    body: body
                )
                onAmortized?()
                dismiss()
            } catch {
                print("Amortize error:", error)
            }
            saving = false
        }
    }

}

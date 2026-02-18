import SwiftUI

struct GroupedCategoryPicker: View {
    let title: String
    let currentCategoryId: Int?
    let onSelect: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [Category] = []
    @State private var groups: [CategoryGroup] = []
    @State private var loading = true
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // Search bar
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textMuted)
                        TextField("Search categories", text: $searchText)
                            .font(.system(size: 15))
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                        }
                    }
                }

                if loading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                } else if searchText.isEmpty {
                    // Browsing mode: grouped sections
                    ForEach(groups) { group in
                        if group.isStandalone {
                            Section {
                                categoryRow(id: group.id, name: group.name, color: group.color, parentName: nil)
                            }
                        } else {
                            Section {
                                ForEach(group.children) { child in
                                    categoryRow(id: child.id, name: child.name, color: group.color, parentName: nil)
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: group.color))
                                        .frame(width: 8, height: 8)
                                    Text(group.name)
                                }
                            }
                        }
                    }
                } else {
                    // Search mode: flat filtered list
                    Section {
                        ForEach(filteredCategories, id: \.category.id) { item in
                            categoryRow(
                                id: item.category.id,
                                name: item.category.name,
                                color: item.category.color ?? "#999",
                                parentName: item.parentName
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { loadCategories() }
    }

    // MARK: - Search

    private var filteredCategories: [(category: Category, parentName: String?)] {
        let idsWithChildren = Set(categories.compactMap { $0.parent_id })
        let selectable = categories.filter { !idsWithChildren.contains($0.id) }

        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        return selectable
            .filter { cat in
                let nameMatch = cat.name.localizedCaseInsensitiveContains(searchText)
                let parentName = cat.parent_id.flatMap { categoryById[$0]?.name }
                let parentMatch = parentName?.localizedCaseInsensitiveContains(searchText) ?? false
                return nameMatch || parentMatch
            }
            .map { cat in
                let parentName = cat.parent_id.flatMap { categoryById[$0]?.name }
                return (category: cat, parentName: parentName)
            }
    }

    // MARK: - Row

    private func categoryRow(id: Int, name: String, color: String, parentName: String?) -> some View {
        Button {
            onSelect(id, name)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 10, height: 10)

                Text(name)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.text)

                Spacer()

                if let parentName = parentName {
                    Text(parentName)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textMuted)
                }

                if id == currentCategoryId {
                    Image(systemName: "checkmark")
                        .foregroundColor(Theme.Colors.accent)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadCategories() {
        Task {
            do {
                categories = try await APIClient.shared.request("/api/categories")
                groups = buildGroups(from: categories)
            } catch {
                print("GroupedCategoryPicker load error:", error)
            }
            loading = false
        }
    }

    private func buildGroups(from categories: [Category]) -> [CategoryGroup] {
        var result: [CategoryGroup] = []

        // Expense categories (grouped by parent)
        let expense = categories.filter { $0.category_type == "expense" }
        let childrenByParent = Dictionary(grouping: expense.filter { $0.parent_id != nil },
                                           by: { $0.parent_id! })

        let topLevel = expense
            .filter { $0.parent_id == nil }
            .sorted { ($0.sort_order ?? 999) < ($1.sort_order ?? 999) }

        for cat in topLevel {
            if let children = childrenByParent[cat.id] {
                result.append(CategoryGroup(
                    id: cat.id,
                    name: cat.name,
                    color: cat.color ?? "#999",
                    children: children.sorted { ($0.sort_order ?? 999) < ($1.sort_order ?? 999) },
                    isStandalone: false
                ))
            } else {
                result.append(CategoryGroup(
                    id: cat.id,
                    name: cat.name,
                    color: cat.color ?? "#999",
                    children: [],
                    isStandalone: true
                ))
            }
        }

        // Income categories
        let income = categories.filter { $0.category_type == "income" }
            .sorted { ($0.sort_order ?? 999) < ($1.sort_order ?? 999) }
        if !income.isEmpty {
            result.append(CategoryGroup(
                id: -1,
                name: "Income",
                color: "#0caa41",
                children: income,
                isStandalone: false
            ))
        }

        // Pretax deduction categories
        let deductions = categories.filter { $0.category_type == "pretax_deduction" }
            .sorted { ($0.sort_order ?? 999) < ($1.sort_order ?? 999) }
        if !deductions.isEmpty {
            result.append(CategoryGroup(
                id: -2,
                name: "Pretax Deductions",
                color: "#e00000",
                children: deductions,
                isStandalone: false
            ))
        }

        return result
    }
}

// MARK: - Category Group Model

private struct CategoryGroup: Identifiable {
    let id: Int
    let name: String
    let color: String
    let children: [Category]
    let isStandalone: Bool
}

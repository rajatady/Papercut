//
//  CategoryPickerView.swift
//  Papercut
//

import SwiftUI

struct CategoryPickerView: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedGroup: CategoryGroup?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group filter
                groupFilterBar

                // Category list
                if filteredCategories.isEmpty {
                    EmptyStateView.searchNoResults(query: searchText)
                } else {
                    categoryList
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "Search categories")
        }
    }

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                groupChip(nil, label: "All")

                ForEach(CategoryGroup.allCases, id: \.self) { group in
                    groupChip(group, label: group.abbreviation.uppercased())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.md)
        }
        .background(theme.colors.background)
    }

    private func groupChip(_ group: CategoryGroup?, label: String) -> some View {
        Button {
            withAnimation {
                selectedGroup = group
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(selectedGroup == group ? theme.colors.accent : theme.colors.surface)
                .foregroundStyle(selectedGroup == group ? .white : theme.colors.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var categoryList: some View {
        List {
            ForEach(groupedCategories.keys.sorted(), id: \.self) { group in
                Section(group) {
                    ForEach(groupedCategories[group] ?? [], id: \.code) { category in
                        CategoryRow(
                            category: category,
                            isFollowed: preferencesStore.isFollowing(category.code)
                        ) {
                            toggleCategory(category.code)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Data

    @MainActor
    private var filteredCategories: [Category] {
        var categories = CategoryManager.shared.allCategories

        // Filter by search
        if !searchText.isEmpty {
            categories = categories.filter { $0.matches(searchText: searchText) }
        }

        // Filter by group
        if let group = selectedGroup {
            categories = categories.filter { $0.group == group.rawValue }
        }

        return categories
    }

    private var groupedCategories: [String: [Category]] {
        Dictionary(grouping: filteredCategories, by: { $0.group })
    }

    private func toggleCategory(_ code: String) {
        if preferencesStore.isFollowing(code) {
            preferencesStore.unfollowCategory(code)
        } else {
            preferencesStore.followCategory(code)
        }
    }
}

#Preview {
    CategoryPickerView()
        .environment(PreferencesStore())
        .environment(ThemeManager())
}

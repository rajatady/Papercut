//
//  CategoryBadge.swift
//  Papercut
//

import SwiftUI

struct CategoryBadge: View {
    let category: String
    var isSelected: Bool = false
    var showFullName: Bool = false

    @Environment(ThemeManager.self) private var theme

    @MainActor
    private var displayText: String {
        if showFullName, let cat = CategoryManager.shared.category(forCode: category) {
            return cat.name
        }
        return category
    }

    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? theme.colors.accent : theme.colors.surface)
            .foregroundStyle(isSelected ? .white : theme.colors.textPrimary)
            .clipShape(Capsule())
    }
}

// MARK: - Selectable Category Badge
struct SelectableCategoryBadge: View {
    let category: Category
    @Binding var isSelected: Bool

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(category.code)
                    .font(.caption)
                    .fontWeight(.semibold)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? theme.colors.accent : theme.colors.surface)
            .foregroundStyle(isSelected ? .white : theme.colors.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Row for Lists
struct CategoryRow: View {
    let category: Category
    let isFollowed: Bool
    let onToggle: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.body)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(category.code)
                        .font(.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()

                Image(systemName: isFollowed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isFollowed ? theme.colors.accent : theme.colors.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            CategoryBadge(category: "cs.AI")
            CategoryBadge(category: "cs.LG", isSelected: true)
            CategoryBadge(category: "Machine Learning", showFullName: true)
        }

        CategoryRow(
            category: Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science"),
            isFollowed: true,
            onToggle: {}
        )
        .padding(.horizontal)
    }
    .padding()
    .environment(ThemeManager())
}

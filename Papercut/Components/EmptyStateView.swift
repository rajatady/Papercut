//
//  EmptyStateView.swift
//  Papercut
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(theme.colors.textMuted)

            VStack(spacing: Spacing.md) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.textPrimary)

                Text(message)
                    .font(AppTypography.bodyRegular)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, Spacing.xxxl)
                        .padding(.vertical, Spacing.lg)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preset Empty States
extension EmptyStateView {
    static func noPapers(onRefresh: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "No Papers Yet",
            message: "Papers from your followed categories will appear here. Pull to refresh or select categories in Settings.",
            actionTitle: "Refresh",
            action: onRefresh
        )
    }

    static func noCategories(onSelectCategories: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "folder.badge.plus",
            title: "No Categories Selected",
            message: "Select research categories you're interested in to start seeing papers in your feed.",
            actionTitle: "Select Categories",
            action: onSelectCategories
        )
    }

    static func error(message: String, onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: message,
            actionTitle: "Try Again",
            action: onRetry
        )
    }

    static func offline(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "You're Offline",
            message: "Check your internet connection and try again.",
            actionTitle: "Retry",
            action: onRetry
        )
    }

    static func searchNoResults(query: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "No categories found matching \"\(query)\". Try a different search term."
        )
    }
}

#Preview {
    VStack(spacing: 40) {
        EmptyStateView.noPapers(onRefresh: {})
    }
    .environment(ThemeManager())
}

//
//  FeedToast.swift
//  Papercut
//

import SwiftUI

/// Transient toast notification for non-blocking errors.
struct FeedToast: View {
    let message: String
    let onDismiss: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(theme.colors.textMuted)

            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundStyle(theme.colors.textSecondary)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal, LayoutConstants.Screen.paddingHorizontal)
        .onTapGesture {
            onDismiss()
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "F5F5F3").ignoresSafeArea()

        VStack {
            Spacer()
            FeedToast(message: "Couldn't refresh — showing cached papers") {}
                .padding(.bottom, 40)
        }
    }
    .environment(ThemeManager())
}

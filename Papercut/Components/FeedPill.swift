//
//  FeedPill.swift
//  Papercut
//

import SwiftUI

struct FeedPill: View {
    let icon: String
    let text: String
    let action: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(text)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(theme.colors.textSecondary)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

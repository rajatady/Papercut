//
//  SummaryStyleChip.swift
//  Papercut
//

import SwiftUI

struct SummaryStyleChip: View {
    let style: SummaryStyle
    var isSelected: Bool = false
    var isLoading: Bool = false
    var hasContent: Bool = false
    let action: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: style.iconName)
                        .font(.caption)
                }

                Text(style.displayName)
                    .font(.caption)
                    .fontWeight(.medium)

                if hasContent && !isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, Spacing.sm)
            .background(backgroundStyle)
            .foregroundStyle(chipForegroundStyle)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? style.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var backgroundStyle: Color {
        if isSelected {
            return style.accentColor.opacity(0.15)
        }
        return theme.colors.surface
    }

    private var chipForegroundStyle: Color {
        if isSelected {
            return style.accentColor
        }
        return theme.colors.textPrimary
    }
}

// MARK: - Summary Style Picker Row
struct SummaryStyleRow: View {
    let style: SummaryStyle
    let isEnabled: Bool
    let onToggle: () -> Void

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: style.iconName)
                    .font(.title3)
                    .foregroundStyle(style.accentColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.body)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(style.description)
                        .font(.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isEnabled ? theme.colors.accent : theme.colors.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SummaryStyle.allCases) { style in
                    SummaryStyleChip(
                        style: style,
                        isSelected: style == .tldr,
                        hasContent: style == .keyFindings,
                        action: {}
                    )
                }
            }
            .padding(.horizontal)
        }

        Divider()

        VStack(spacing: 0) {
            ForEach(SummaryStyle.allCases) { style in
                SummaryStyleRow(
                    style: style,
                    isEnabled: SummaryStyle.defaultEnabled.contains(style),
                    onToggle: {}
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                if style != SummaryStyle.allCases.last {
                    Divider()
                        .padding(.leading, 54)
                }
            }
        }
    }
    .environment(ThemeManager())
}

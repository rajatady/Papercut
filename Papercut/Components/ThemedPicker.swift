//
//  ThemedPicker.swift
//  Papercut
//

import SwiftUI

/// A reusable themed dropdown using the native Apple `Menu` picker.
/// Displays a label with the current selection and an icon, styled
/// consistently with the app's design system.
struct ThemedPicker<T: Hashable & Identifiable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    let icon: ((T) -> String)?

    @Environment(ThemeManager.self) private var theme

    init(
        title: String,
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String,
        icon: ((T) -> String)? = nil
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.label = label
        self.icon = icon
    }

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    HStack {
                        if let icon {
                            Label(label(option), systemImage: icon(option))
                        } else {
                            Text(label(option))
                        }
                    }
                    .tag(option)
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon(selection))
                        .font(.caption2)
                        .foregroundStyle(theme.colors.accent)
                }

                Text(label(selection))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.colors.textPrimary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.textMuted)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(theme.colors.surface.opacity(theme.isDark ? 0.3 : 0.7))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(theme.colors.surface, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ThemedPicker(
        title: "Sort by",
        selection: .constant(ArXivSortBy.relevance),
        options: ArXivSortBy.searchCases,
        label: { $0.displayName },
        icon: { $0.iconName }
    )
    .padding()
    .environment(ThemeManager())
}

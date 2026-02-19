//
//  SummaryStylePicker.swift
//  Papercut
//

import SwiftUI

struct SummaryStylePicker: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SummaryStyle.allCases) { style in
                        SummaryStyleRow(
                            style: style,
                            isEnabled: preferencesStore.isStyleEnabled(style)
                        ) {
                            toggleStyle(style)
                        }
                    }
                } header: {
                    Text("Enabled Styles")
                } footer: {
                    Text("Select which summary styles appear as options when viewing papers. At least one style must be enabled.")
                }

                Section {
                    ForEach(SummaryStyle.allCases) { style in
                        if preferencesStore.isStyleEnabled(style) {
                            defaultStyleRow(style)
                        }
                    }
                } header: {
                    Text("Default Style")
                } footer: {
                    Text("The default style will be automatically selected when viewing a paper.")
                }
            }
            .navigationTitle("Summary Styles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func defaultStyleRow(_ style: SummaryStyle) -> some View {
        Button {
            preferencesStore.setDefaultStyle(style)
        } label: {
            HStack {
                Image(systemName: style.iconName)
                    .foregroundStyle(style.accentColor)
                    .frame(width: 24)

                Text(style.displayName)
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()

                if preferencesStore.defaultSummaryStyle == style {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.colors.accent)
                }
            }
        }
    }

    private func toggleStyle(_ style: SummaryStyle) {
        if preferencesStore.isStyleEnabled(style) {
            preferencesStore.disableStyle(style)
        } else {
            preferencesStore.enableStyle(style)
        }
    }
}

#Preview {
    SummaryStylePicker()
        .environment(PreferencesStore())
        .environment(ThemeManager())
}

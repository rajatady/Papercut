//
//  SettingsView.swift
//  Papercut
//

import SwiftUI

struct SettingsView: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var showingCategoryPicker = false
    @State private var showingStylePicker = false
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            List {
                // Search
                Section {
                    Button {
                        showingSearch = true
                    } label: {
                        Label("Search Papers", systemImage: "magnifyingglass")
                            .foregroundStyle(theme.colors.textPrimary)
                    }
                }

                // Appearance Section
                Section {
                    HStack {
                        Label {
                            Text("Dark Mode")
                        } icon: {
                            Image(systemName: theme.isDark ? "moon.fill" : "sun.max.fill")
                                .foregroundStyle(theme.isDark ? .indigo : .orange)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { theme.isDark },
                            set: { _ in theme.toggleTheme() }
                        ))
                        .labelsHidden()
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Switch between light and dark mode.")
                }

                // Categories Section
                Section {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        HStack {
                            Label("Followed Categories", systemImage: "folder")
                                .foregroundStyle(theme.colors.textPrimary)

                            Spacer()

                            Text("\(preferencesStore.followedCategories.count)")
                                .foregroundStyle(theme.colors.textSecondary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                    }

                    if !preferencesStore.followedCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(preferencesStore.followedCategories, id: \.self) { code in
                                    CategoryBadge(category: code, isSelected: true)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Papers from these categories will appear in your feed.")
                }

                // Summary Section
                Section {
                    Button {
                        showingStylePicker = true
                    } label: {
                        HStack {
                            Label("Summary Styles", systemImage: "text.quote")
                                .foregroundStyle(theme.colors.textPrimary)

                            Spacer()

                            Text("\(preferencesStore.enabledSummaryStyles.count)")
                                .foregroundStyle(theme.colors.textSecondary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { preferencesStore.autoSummarize },
                        set: { preferencesStore.setAutoSummarize($0) }
                    )) {
                        Label("Auto-Summarize", systemImage: "sparkles")
                    }
                } header: {
                    Text("Summarization")
                } footer: {
                    Text("When auto-summarize is enabled, papers will be automatically summarized as they appear in your feed.")
                }

                // Feed Section
                Section {
                    Picker(selection: Binding(
                        get: { preferencesStore.feedSortOrder },
                        set: { preferencesStore.setFeedSortOrder($0) }
                    )) {
                        ForEach(FeedSortOrder.allCases) { order in
                            Label(order.displayName, systemImage: order.iconName)
                                .tag(order)
                        }
                    } label: {
                        Label("Sort Order", systemImage: "arrow.up.arrow.down")
                    }

                    Stepper(value: Binding(
                        get: { preferencesStore.paperRetentionDays },
                        set: { preferencesStore.setPaperRetentionDays($0) }
                    ), in: 7...365) {
                        HStack {
                            Label("Keep Papers", systemImage: "clock")
                            Spacer()
                            Text("\(preferencesStore.paperRetentionDays) days")
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                } header: {
                    Text("Feed")
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    Link(destination: URL(string: "https://arxiv.org") ?? URL(string: "about:blank")!) {
                        HStack {
                            Label("ArXiv Website", systemImage: "link")
                                .foregroundStyle(theme.colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Papercut uses Apple's on-device AI for paper summarization. Paper data is sourced from arXiv.org.")
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        preferencesStore.resetToDefaults()
                    } label: {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView()
            }
            .sheet(isPresented: $showingStylePicker) {
                SummaryStylePicker()
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(PreferencesStore())
        .environment(ThemeManager())
}

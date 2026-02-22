//
//  SettingsView.swift
//  Papercut
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var showingCategoryPicker = false
    @State private var showingStylePicker = false
    @State private var notificationsEnabled: Bool = false
    @State private var notificationsDeniedByOS = false
    @State private var digestTime = Date()

    var body: some View {
        NavigationStack {
            List {
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

                // Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                    .onChange(of: notificationsEnabled) { _, enabled in
                        Task {
                            if enabled {
                                let granted = await preferencesStore.setNotificationsEnabled(true)
                                if !granted {
                                    notificationsEnabled = false
                                    // Check if denied at OS level
                                    let status = await NotificationManager.shared.authorizationStatus()
                                    notificationsDeniedByOS = (status == .denied)
                                }
                            } else {
                                await preferencesStore.setNotificationsEnabled(false)
                            }
                        }
                    }

                    if notificationsDeniedByOS {
                        HStack {
                            Text("Notifications are disabled in system settings")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "E4A853"))

                            Spacer()

                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                    }

                    if preferencesStore.notificationsEnabled {
                        Toggle(isOn: Binding(
                            get: { preferencesStore.dailyDigestEnabled },
                            set: { preferencesStore.setDailyDigestEnabled($0) }
                        )) {
                            Label("Daily Digest", systemImage: "newspaper")
                        }

                        if preferencesStore.dailyDigestEnabled {
                            DatePicker(
                                selection: $digestTime,
                                displayedComponents: .hourAndMinute
                            ) {
                                Label("Delivery Time", systemImage: "clock")
                            }
                            .onChange(of: digestTime) { _, newTime in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                                preferencesStore.setDailyDigestTime(
                                    hour: components.hour ?? 9,
                                    minute: components.minute ?? 0
                                )
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { preferencesStore.topicNotificationsEnabled },
                            set: { preferencesStore.setTopicNotificationsEnabled($0) }
                        )) {
                            Label("Topic Updates", systemImage: "bookmark")
                        }

                        Toggle(isOn: Binding(
                            get: { preferencesStore.newFeedItemsNotificationEnabled },
                            set: { preferencesStore.setNewFeedItemsNotificationEnabled($0) }
                        )) {
                            Label("New Papers Alert", systemImage: "doc.badge.plus")
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified about new papers in your research areas.")
                }

                // Feedback & Support
                Section {
                    feedbackLink(
                        icon: "ladybug",
                        iconColor: .red,
                        title: "Report a Bug",
                        urlString: Self.bugReportURL
                    )

                    feedbackLink(
                        icon: "lightbulb",
                        iconColor: Color(hex: "E4A853"),
                        title: "Request a Feature",
                        urlString: Self.featureRequestURL
                    )

                    feedbackLink(
                        icon: "star",
                        iconColor: Color(hex: "E4C95B"),
                        title: "Star on GitHub",
                        urlString: "https://github.com/rajatady/Papercut"
                    )
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Papercut is open source. Your feedback helps make it better.")
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(theme.colors.textSecondary)
                    }

                    Link(destination: URL(string: "https://arxiv.org")!) {
                        HStack {
                            Label("ArXiv Website", systemImage: "link")
                                .foregroundStyle(theme.colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/rajatady/Papercut")!) {
                        HStack {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
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
            .onAppear {
                notificationsEnabled = preferencesStore.notificationsEnabled
                var components = DateComponents()
                components.hour = preferencesStore.dailyDigestHour
                components.minute = preferencesStore.dailyDigestMinute
                digestTime = Calendar.current.date(from: components) ?? Date()
            }
        }
    }
}

// MARK: - Feedback Helpers
extension SettingsView {
    private static let repo = "rajatady/Papercut"

    static var bugReportURL: String {
        let title = ""
        let body = """
        **Describe the bug**
        A clear description of what the bug is.

        **Steps to reproduce**
        1.
        2.
        3.

        **Expected behavior**


        **Device info**
        - Device: \(deviceName)
        - iOS: \(UIDevice.current.systemVersion)
        - App version: 1.0.0
        """
        return "https://github.com/\(repo)/issues/new?labels=bug&title=\(title.urlEncoded)&body=\(body.urlEncoded)"
    }

    static var featureRequestURL: String {
        let body = """
        **What would you like?**
        A clear description of the feature.

        **Why is this useful?**


        **Anything else?**

        """
        return "https://github.com/\(repo)/issues/new?labels=enhancement&title=&body=\(body.urlEncoded)"
    }

    private static var deviceName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? UIDevice.current.model
            }
        }
    }

    private func feedbackLink(icon: String, iconColor: Color, title: String, urlString: String) -> some View {
        Link(destination: URL(string: urlString)!) {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(theme.colors.textPrimary)
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }
        }
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

#Preview {
    SettingsView()
        .environment(PreferencesStore())
        .environment(ThemeManager())
}

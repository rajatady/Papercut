//
//  NotificationDebugView.swift
//  Papercut
//

#if DEBUG

import SwiftUI
import UserNotifications

// MARK: - Debug Logger

@Observable
@MainActor
final class DebugLogger {
    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: Level

        enum Level {
            case info, success, warning, error

            var icon: String {
                switch self {
                case .info: return "circle.fill"
                case .success: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                }
            }

            var color: Color {
                switch self {
                case .info: return .secondary
                case .success: return .green
                case .warning: return Color(hex: "E4A853")
                case .error: return .red
                }
            }
        }

        var timeString: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f.string(from: timestamp)
        }
    }

    var entries: [Entry] = []

    func log(_ message: String, level: Entry.Level = .info) {
        entries.append(Entry(timestamp: Date(), message: message, level: level))
    }

    func success(_ message: String) { log(message, level: .success) }
    func warn(_ message: String) { log(message, level: .warning) }
    func error(_ message: String) { log(message, level: .error) }
    func clear() { entries.removeAll() }
}

// MARK: - Debug View

struct NotificationDebugView: View {
    @Environment(PreferencesStore.self) private var preferencesStore
    @Environment(ThemeManager.self) private var theme

    @State private var logger = DebugLogger()
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var topicCount = 0
    @State private var isRunningTopicChecker = false
    @State private var isRunningFeedChecker = false

    var body: some View {
        List {
            statusSection
            quickTriggerSection
            backgroundCheckerSection
            pendingNotificationsSection
            logConsoleSection
        }
        .navigationTitle("Notification Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshStatus()
        }
    }

    // MARK: - Status Dashboard

    private var statusSection: some View {
        Section {
            statusRow("OS Permission", value: permissionLabel, color: permissionColor)
            statusRow("Master Toggle", value: preferencesStore.notificationsEnabled ? "ON" : "OFF",
                       color: preferencesStore.notificationsEnabled ? .green : .red)
            statusRow("Daily Digest", value: preferencesStore.dailyDigestEnabled ? "ON" : "OFF",
                       color: preferencesStore.dailyDigestEnabled ? .green : .secondary)
            statusRow("Topic Updates", value: preferencesStore.topicNotificationsEnabled ? "ON" : "OFF",
                       color: preferencesStore.topicNotificationsEnabled ? .green : .secondary)
            statusRow("Feed Alerts", value: preferencesStore.newFeedItemsNotificationEnabled ? "ON" : "OFF",
                       color: preferencesStore.newFeedItemsNotificationEnabled ? .green : .secondary)
            statusRow("Digest Time", value: String(format: "%02d:%02d", preferencesStore.dailyDigestHour, preferencesStore.dailyDigestMinute), color: .secondary)
            statusRow("Categories", value: "\(preferencesStore.followedCategories.count)", color: .secondary)
            statusRow("Topics", value: "\(topicCount)", color: .secondary)
            statusRow("Last Known Paper", value: preferencesStore.lastKnownLatestPaperId ?? "nil", color: .secondary)
        } header: {
            Text("Status")
        }
    }

    // MARK: - Quick Triggers

    private var quickTriggerSection: some View {
        Section {
            Button {
                fireNotification(
                    type: .dailyDigest,
                    title: "Your Daily Digest",
                    body: "New research papers are waiting in your feed."
                )
            } label: {
                Label("Fire Daily Digest", systemImage: "newspaper")
            }

            Button {
                fireNotification(
                    type: .topicUpdate,
                    title: "Transformer Architectures",
                    body: "5 new papers found",
                    customId: "topic_update_debug_test"
                )
            } label: {
                Label("Fire Topic Update", systemImage: "bookmark")
            }

            Button {
                fireNotification(
                    type: .newFeedItems,
                    title: "New Research Available",
                    body: "12 new papers in your feed"
                )
            } label: {
                Label("Fire New Feed Items", systemImage: "doc.badge.plus")
            }

            Button {
                fireAllNotifications()
            } label: {
                Label("Fire All (staggered)", systemImage: "bell.badge.waveform")
                    .foregroundStyle(Color(hex: "E4A853"))
            }
        } header: {
            Text("Quick Triggers")
        } footer: {
            Text("Fires a real local notification in ~2 seconds. Shows as a banner even while the app is open.")
        }
    }

    // MARK: - Background Checkers

    private var backgroundCheckerSection: some View {
        Section {
            Button {
                Task { await runTopicChecker() }
            } label: {
                HStack {
                    Label("Run Topic Checker", systemImage: "arrow.triangle.2.circlepath")
                    if isRunningTopicChecker {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isRunningTopicChecker)

            Button {
                Task { await runFeedChecker() }
            } label: {
                HStack {
                    Label("Run Feed Checker", systemImage: "arrow.triangle.2.circlepath")
                    if isRunningFeedChecker {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isRunningFeedChecker)

            Button {
                scheduleAllTasks()
            } label: {
                Label("Schedule BG Tasks", systemImage: "clock.badge.checkmark")
            }

            Button {
                cancelAllTasks()
            } label: {
                Label("Cancel BG Tasks", systemImage: "clock.badge.xmark")
                    .foregroundStyle(.red)
            }

            Button {
                Task { await requestPermission() }
            } label: {
                Label("Request Permission", systemImage: "lock.open")
            }

            Button {
                rescheduleAll()
            } label: {
                Label("Reschedule All Notifications", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Background Tasks & Control")
        } footer: {
            Text("Topic/Feed checkers make real arXiv API calls. They will schedule notifications if new papers are found.")
        }
    }

    // MARK: - Pending Notifications

    private var pendingNotificationsSection: some View {
        Section {
            if pendingNotifications.isEmpty {
                Text("No pending notifications")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
            } else {
                ForEach(pendingNotifications, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.identifier)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                        Text(request.content.title)
                            .font(.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                        Text(triggerDescription(request.trigger))
                            .font(.caption2)
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                }
            }

            Button {
                Task { await refreshPendingNotifications() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button(role: .destructive) {
                cancelAllNotifications()
            } label: {
                Label("Cancel All Notifications", systemImage: "trash")
            }
        } header: {
            HStack {
                Text("Pending Notifications")
                Spacer()
                Text("\(pendingNotifications.count)")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
            }
        }
    }

    // MARK: - Log Console

    private var logConsoleSection: some View {
        Section {
            if logger.entries.isEmpty {
                Text("No log entries yet")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
            } else {
                ForEach(logger.entries) { entry in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: entry.level.icon)
                            .font(.system(size: 8))
                            .foregroundStyle(entry.level.color)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.timeString)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(theme.colors.textTertiary)
                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(theme.colors.textPrimary)
                        }
                    }
                }
            }

            Button {
                copyLogs()
            } label: {
                Label("Copy Logs", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                logger.clear()
            } label: {
                Label("Clear Log", systemImage: "trash")
            }
        } header: {
            HStack {
                Text("Log")
                Spacer()
                Text("\(logger.entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textMuted)
            }
        }
    }

    // MARK: - Helpers

    private func statusRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private var permissionLabel: String {
        switch permissionStatus {
        case .authorized: return "authorized"
        case .denied: return "DENIED"
        case .notDetermined: return "not determined"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private var permissionColor: Color {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return Color(hex: "E4A853")
        @unknown default: return .secondary
        }
    }

    private func triggerDescription(_ trigger: UNNotificationTrigger?) -> String {
        guard let trigger else { return "no trigger" }
        if let calTrigger = trigger as? UNCalendarNotificationTrigger {
            let dc = calTrigger.dateComponents
            let h = dc.hour.map { String(format: "%02d", $0) } ?? "??"
            let m = dc.minute.map { String(format: "%02d", $0) } ?? "??"
            return "Calendar: \(h):\(m) repeats=\(calTrigger.repeats)"
        } else if let timeTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return "TimeInterval: \(timeTrigger.timeInterval)s repeats=\(timeTrigger.repeats)"
        } else {
            return String(describing: type(of: trigger))
        }
    }

    // MARK: - Actions

    private func refreshStatus() async {
        permissionStatus = await NotificationManager.shared.authorizationStatus()
        topicCount = AppDependencies.shared.topicRepository.fetchAllTopics().count
        await refreshPendingNotifications()
        logger.log("Status refreshed — permission=\(permissionLabel), topics=\(topicCount)")
    }

    private func refreshPendingNotifications() async {
        pendingNotifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
        logger.log("Fetched \(pendingNotifications.count) pending notifications")
    }

    private func fireNotification(type: NotificationType, title: String, body: String, customId: String? = nil) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = NotificationRequest(
            type: type,
            title: title,
            body: body,
            trigger: trigger,
            userInfo: ["type": type.rawValue, "debug": true],
            customIdentifier: customId
        )
        NotificationManager.shared.schedule(request)
        logger.success("Scheduled \(request.identifier) — \"\(title): \(body)\" — fires in 2s")
        Task { await refreshPendingNotifications() }
    }

    private func fireAllNotifications() {
        logger.log("Firing all notification types staggered...")

        let types: [(NotificationType, String, String, String?, TimeInterval)] = [
            (.dailyDigest, "Your Daily Digest", "New research papers are waiting.", nil, 2),
            (.topicUpdate, "Transformer Architectures", "5 new papers found", "topic_update_debug_all", 5),
            (.newFeedItems, "New Research Available", "12 new papers in your feed", nil, 8)
        ]

        for (type, title, body, customId, delay) in types {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = NotificationRequest(
                type: type,
                title: title,
                body: body,
                trigger: trigger,
                userInfo: ["type": type.rawValue, "debug": true],
                customIdentifier: customId
            )
            NotificationManager.shared.schedule(request)
            logger.success("Queued \(request.identifier) — fires in \(Int(delay))s")
        }

        Task { await refreshPendingNotifications() }
    }

    private func runTopicChecker() async {
        isRunningTopicChecker = true
        defer { isRunningTopicChecker = false }

        let topics = AppDependencies.shared.topicRepository.fetchAllTopics()
        logger.log("Starting topic checker — \(topics.count) topics found")

        if topics.isEmpty {
            logger.warn("No topics to check. Create a topic first.")
            return
        }

        for topic in topics {
            logger.log("  Checking: \"\(topic.name)\" (active=\(topic.isActive), papers=\(topic.paperIds.count))")
        }

        let checker = TopicUpdateChecker(
            topicRepository: AppDependencies.shared.topicRepository,
            notificationManager: NotificationManager.shared
        )
        await checker.run()

        // Re-fetch to see updated state
        let updated = AppDependencies.shared.topicRepository.fetchAllTopics()
        for topic in updated {
            logger.success("  \"\(topic.name)\" — now \(topic.paperIds.count) papers, lastChecked=\(topic.lastCheckedAt?.formatted() ?? "never")")
        }

        logger.success("Topic checker complete")
        await refreshPendingNotifications()
    }

    private func runFeedChecker() async {
        isRunningFeedChecker = true
        defer { isRunningFeedChecker = false }

        let categories = preferencesStore.followedCategories
        let lastKnown = preferencesStore.lastKnownLatestPaperId

        logger.log("Starting feed checker — \(categories.count) categories, lastKnown=\(lastKnown ?? "nil")")

        if categories.isEmpty {
            logger.warn("No followed categories. Follow some categories first.")
            return
        }

        let checker = FeedUpdateChecker(
            paperRepository: AppDependencies.shared.paperRepository,
            preferencesStore: preferencesStore
        )
        await checker.run()

        let newLastKnown = preferencesStore.lastKnownLatestPaperId
        if newLastKnown != lastKnown {
            logger.success("Last known paper updated: \(lastKnown ?? "nil") → \(newLastKnown ?? "nil")")
        } else {
            logger.log("Last known paper unchanged: \(newLastKnown ?? "nil")")
        }

        logger.success("Feed checker complete")
        await refreshPendingNotifications()
    }

    private func scheduleAllTasks() {
        BackgroundTaskManager.shared.scheduleAll(preferences: preferencesStore.preferences)
        logger.success("BackgroundTaskManager.scheduleAll() called")
        logger.log("  topicNotifications=\(preferencesStore.topicNotificationsEnabled), feedNotifications=\(preferencesStore.newFeedItemsNotificationEnabled)")
    }

    private func cancelAllTasks() {
        BackgroundTaskManager.shared.scheduleAll(
            preferences: UserPreferences(notificationsEnabled: false)
        )
        logger.warn("All background tasks cancelled")
    }

    private func requestPermission() async {
        logger.log("Requesting notification permission...")
        let granted = await NotificationManager.shared.requestPermission()
        if granted {
            logger.success("Permission granted")
        } else {
            logger.error("Permission denied or failed")
        }
        permissionStatus = await NotificationManager.shared.authorizationStatus()
    }

    private func rescheduleAll() {
        NotificationManager.shared.rescheduleAll(preferences: preferencesStore.preferences)
        logger.success("NotificationManager.rescheduleAll() called")
        Task { await refreshPendingNotifications() }
    }

    private func cancelAllNotifications() {
        NotificationManager.shared.cancelAll()
        logger.warn("All notifications cancelled")
        Task { await refreshPendingNotifications() }
    }

    private func copyLogs() {
        let levelLabel: (DebugLogger.Entry.Level) -> String = { level in
            switch level {
            case .info: return "INFO"
            case .success: return "OK"
            case .warning: return "WARN"
            case .error: return "ERR"
            }
        }
        let text = logger.entries.map { entry in
            "[\(entry.timeString)] [\(levelLabel(entry.level))] \(entry.message)"
        }.joined(separator: "\n")

        UIPasteboard.general.string = text
        logger.success("Copied \(logger.entries.count) log entries to clipboard")
    }
}

#Preview {
    NavigationStack {
        NotificationDebugView()
            .environment(PreferencesStore())
            .environment(ThemeManager())
    }
}

#endif

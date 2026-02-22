//
//  BackgroundTaskManager.swift
//  Papercut
//

import Foundation
import BackgroundTasks

/// Manages BGAppRefreshTask registration and scheduling for background content checks.
///
/// Requires `BGTaskSchedulerPermittedIdentifiers` in Info.plist:
/// - com.papercut.refresh.topics
/// - com.papercut.refresh.feed
///
/// Add via Xcode → Target → Info → BGTaskSchedulerPermittedIdentifiers.
@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    static let topicRefreshIdentifier = "com.papercut.refresh.topics"
    static let feedRefreshIdentifier = "com.papercut.refresh.feed"

    private init() {}

    // MARK: - Registration (must be called before app finishes launching)

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.topicRefreshIdentifier,
            using: nil
        ) { task in
            self.handleTopicRefresh(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.feedRefreshIdentifier,
            using: nil
        ) { task in
            self.handleFeedRefresh(task: task as! BGAppRefreshTask)
        }
    }

    // MARK: - Scheduling

    func scheduleAll(preferences: UserPreferences) {
        guard preferences.notificationsEnabled else {
            cancelAll()
            return
        }

        if preferences.topicNotificationsEnabled {
            scheduleTopicRefresh()
        } else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.topicRefreshIdentifier)
        }

        if preferences.newFeedItemsNotificationEnabled {
            scheduleFeedRefresh()
        } else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.feedRefreshIdentifier)
        }
    }

    private func scheduleTopicRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.topicRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BackgroundTaskManager: failed to schedule topic refresh — \(error)")
        }
    }

    private func scheduleFeedRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.feedRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BackgroundTaskManager: failed to schedule feed refresh — \(error)")
        }
    }

    private func cancelAll() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.topicRefreshIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.feedRefreshIdentifier)
    }

    // MARK: - Task Handlers

    private func handleTopicRefresh(task: BGAppRefreshTask) {
        // Re-schedule for next run
        scheduleTopicRefresh()

        let workTask = Task {
            let checker = TopicUpdateChecker(
                topicRepository: AppDependencies.shared.topicRepository,
                notificationManager: NotificationManager.shared
            )
            await checker.run()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func handleFeedRefresh(task: BGAppRefreshTask) {
        // Re-schedule for next run
        scheduleFeedRefresh()

        let workTask = Task {
            let checker = FeedUpdateChecker(
                paperRepository: AppDependencies.shared.paperRepository,
                preferencesStore: AppDependencies.shared.preferencesStore
            )
            await checker.run()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

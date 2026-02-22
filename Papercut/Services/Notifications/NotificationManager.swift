//
//  NotificationManager.swift
//  Papercut
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Foreground Delivery

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound even when app is in foreground
        completionHandler([.banner, .sound])
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("NotificationManager: permission request failed — \(error)")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    func schedule(_ request: NotificationRequest) {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = request.type.categoryIdentifier
        content.userInfo = request.userInfo

        let unRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: request.trigger
        )

        // Remove existing with same identifier, then add
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        center.add(unRequest) { error in
            if let error {
                print("NotificationManager: failed to schedule \(request.identifier) — \(error)")
            }
        }
    }

    func cancel(type: NotificationType) {
        center.removePendingNotificationRequests(withIdentifiers: [type.rawValue])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Reschedule All

    /// Single entry point called after any notification preference change.
    /// Reads current preferences and schedules/cancels all notification types.
    func rescheduleAll(preferences: UserPreferences) {
        guard preferences.notificationsEnabled else {
            cancelAll()
            return
        }

        // Daily Digest
        if preferences.dailyDigestEnabled {
            scheduleDailyDigest(hour: preferences.dailyDigestHour, minute: preferences.dailyDigestMinute)
        } else {
            cancel(type: .dailyDigest)
        }

        // Background task notifications (topic updates, new feed items)
        BackgroundTaskManager.shared.scheduleAll(preferences: preferences)
    }

    // MARK: - Daily Digest

    private func scheduleDailyDigest(hour: Int, minute: Int) {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = NotificationRequest(
            type: .dailyDigest,
            title: "Your Daily Digest",
            body: "New research papers are waiting in your feed.",
            trigger: trigger,
            userInfo: ["type": NotificationType.dailyDigest.rawValue]
        )

        schedule(request)
    }
}

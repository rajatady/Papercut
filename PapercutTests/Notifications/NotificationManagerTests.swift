//
//  NotificationManagerTests.swift
//  PapercutTests
//

import Testing
import UserNotifications
@testable import Papercut

@Suite("Notification Manager")
struct NotificationManagerTests {

    @Test func notificationType_rawValues() {
        #expect(NotificationType.dailyDigest.rawValue == "daily_digest")
        #expect(NotificationType.dailyDigest.categoryIdentifier == "daily_digest")
    }

    @Test func notificationType_allCases() {
        #expect(NotificationType.allCases.count >= 1)
        #expect(NotificationType.allCases.contains(.dailyDigest))
    }

    @Test func notificationRequest_identifier() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = NotificationRequest(
            type: .dailyDigest,
            title: "Test",
            body: "Test body",
            trigger: trigger,
            userInfo: [:]
        )
        #expect(request.identifier == "daily_digest")
    }

    @Test @MainActor func rescheduleAll_masterDisabled_cancelsAll() async {
        var prefs = UserPreferences.default
        prefs.notificationsEnabled = false
        prefs.dailyDigestEnabled = true

        // This should not crash and should call cancelAll internally
        NotificationManager.shared.rescheduleAll(preferences: prefs)

        // Verify no pending notifications
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let digestRequests = pending.filter { $0.identifier == NotificationType.dailyDigest.rawValue }
        #expect(digestRequests.isEmpty)
    }
}

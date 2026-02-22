//
//  TopicUpdateCheckerTests.swift
//  PapercutTests
//

import Testing
import UserNotifications
@testable import Papercut

@Suite("Topic Update Checker")
struct TopicUpdateCheckerTests {

    @Test func notificationType_topicUpdate_rawValue() {
        #expect(NotificationType.topicUpdate.rawValue == "topic_update")
        #expect(NotificationType.topicUpdate.categoryIdentifier == "topic_update")
    }

    @Test func notificationType_newFeedItems_rawValue() {
        #expect(NotificationType.newFeedItems.rawValue == "new_feed_items")
        #expect(NotificationType.newFeedItems.categoryIdentifier == "new_feed_items")
    }

    @Test func notificationType_allCases_includesNewTypes() {
        #expect(NotificationType.allCases.contains(.topicUpdate))
        #expect(NotificationType.allCases.contains(.newFeedItems))
        #expect(NotificationType.allCases.count >= 3)
    }

    @Test func notificationRequest_customIdentifier_overridesType() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = NotificationRequest(
            type: .topicUpdate,
            title: "Test",
            body: "Test body",
            trigger: trigger,
            userInfo: [:],
            customIdentifier: "topic_update_abc123"
        )
        #expect(request.identifier == "topic_update_abc123")
    }

    @Test func notificationRequest_noCustomIdentifier_usesTypeRawValue() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = NotificationRequest(
            type: .newFeedItems,
            title: "Test",
            body: "Test body",
            trigger: trigger,
            userInfo: [:]
        )
        #expect(request.identifier == "new_feed_items")
    }
}

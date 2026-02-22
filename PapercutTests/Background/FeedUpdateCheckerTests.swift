//
//  FeedUpdateCheckerTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite("Feed Update Checker")
struct FeedUpdateCheckerTests {

    @Test func backgroundTaskManager_identifiers() {
        #expect(BackgroundTaskManager.topicRefreshIdentifier == "com.papercut.refresh.topics")
        #expect(BackgroundTaskManager.feedRefreshIdentifier == "com.papercut.refresh.feed")
    }

    @Test func preferences_topicNotifications_defaultTrue() {
        let prefs = UserPreferences.default
        #expect(prefs.topicNotificationsEnabled == true)
    }

    @Test func preferences_newFeedItemsNotification_defaultTrue() {
        let prefs = UserPreferences.default
        #expect(prefs.newFeedItemsNotificationEnabled == true)
    }

    @Test func preferences_lastKnownLatestPaperId_defaultNil() {
        let prefs = UserPreferences.default
        #expect(prefs.lastKnownLatestPaperId == nil)
    }

    @Test func preferences_lastKnownLatestPaperId_roundTrip() {
        var prefs = UserPreferences.default
        prefs.lastKnownLatestPaperId = "2401.12345"

        let data = try! JSONEncoder().encode(prefs)
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.lastKnownLatestPaperId == "2401.12345")
    }

    @Test func preferences_topicNotifications_roundTrip() {
        var prefs = UserPreferences.default
        prefs.topicNotificationsEnabled = false

        let data = try! JSONEncoder().encode(prefs)
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.topicNotificationsEnabled == false)
    }

    @Test func preferences_newFeedItemsNotification_roundTrip() {
        var prefs = UserPreferences.default
        prefs.newFeedItemsNotificationEnabled = false

        let data = try! JSONEncoder().encode(prefs)
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.newFeedItemsNotificationEnabled == false)
    }

    @Test func backwardCompatibility_missingBackgroundNotificationFields() {
        let oldJSON = """
        {
            "followedCategories": ["cs.AI"],
            "enabledSummaryStyles": ["tldr"],
            "defaultSummaryStyle": "tldr",
            "autoSummarize": true,
            "feedSortOrder": "newest",
            "paperRetentionDays": 30,
            "hasCompletedOnboarding": true,
            "notificationsEnabled": true,
            "dailyDigestEnabled": true
        }
        """

        let data = oldJSON.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.topicNotificationsEnabled == true)
        #expect(decoded.newFeedItemsNotificationEnabled == true)
        #expect(decoded.lastKnownLatestPaperId == nil)
    }
}

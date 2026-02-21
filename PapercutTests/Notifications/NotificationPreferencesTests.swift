//
//  NotificationPreferencesTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite("Notification Preferences")
struct NotificationPreferencesTests {

    @Test func defaultValues() {
        let prefs = UserPreferences.default
        #expect(prefs.notificationsEnabled == false)
        #expect(prefs.dailyDigestEnabled == true)
        #expect(prefs.dailyDigestHour == 9)
        #expect(prefs.dailyDigestMinute == 0)
        #expect(prefs.hasRequestedNotificationPermission == false)
    }

    @Test func dailyDigestTime_roundTrip() {
        var prefs = UserPreferences.default
        prefs.dailyDigestHour = 14
        prefs.dailyDigestMinute = 30

        let data = try! JSONEncoder().encode(prefs)
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.dailyDigestHour == 14)
        #expect(decoded.dailyDigestMinute == 30)
    }

    @Test func notificationsEnabled_roundTrip() {
        var prefs = UserPreferences.default
        prefs.notificationsEnabled = true

        let data = try! JSONEncoder().encode(prefs)
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.notificationsEnabled == true)
    }

    @Test func backwardCompatibility_missingNotificationFields() {
        // Simulate old preferences JSON without notification fields
        let oldJSON = """
        {
            "followedCategories": ["cs.AI"],
            "enabledSummaryStyles": ["tldr"],
            "defaultSummaryStyle": "tldr",
            "autoSummarize": true,
            "feedSortOrder": "newest",
            "paperRetentionDays": 30,
            "hasCompletedOnboarding": true
        }
        """

        let data = oldJSON.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.notificationsEnabled == false)
        #expect(decoded.dailyDigestEnabled == true)
        #expect(decoded.dailyDigestHour == 9)
        #expect(decoded.dailyDigestMinute == 0)
        #expect(decoded.hasRequestedNotificationPermission == false)
    }
}

//
//  PreferencesStore.swift
//  Papercut
//

import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class PreferencesStore {
    private let userDefaultsKey = "userPreferences"
    private let userDefaults: UserDefaults

    private(set) var preferences: UserPreferences {
        didSet {
            save()
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.preferences = Self.load(from: userDefaults)
    }

    // MARK: - Persistence

    private static func load(from userDefaults: UserDefaults) -> UserPreferences {
        guard let data = userDefaults.data(forKey: "userPreferences"),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return .default
        }
        return preferences
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: userDefaultsKey)
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        preferences.hasCompletedOnboarding
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }

    // MARK: - Categories

    var followedCategories: [String] {
        preferences.followedCategories
    }

    func followCategory(_ code: String) {
        guard !preferences.followedCategories.contains(code) else { return }
        preferences.followedCategories.append(code)
    }

    func unfollowCategory(_ code: String) {
        preferences.followedCategories.removeAll { $0 == code }
    }

    func isFollowing(_ code: String) -> Bool {
        preferences.followedCategories.contains(code)
    }

    func setFollowedCategories(_ categories: [String]) {
        preferences.followedCategories = categories
    }

    // MARK: - Summary Styles

    var enabledSummaryStyles: Set<SummaryStyle> {
        preferences.enabledStyles
    }

    var defaultSummaryStyle: SummaryStyle {
        preferences.defaultStyle
    }

    func enableStyle(_ style: SummaryStyle) {
        var styles = preferences.enabledStyles
        styles.insert(style)
        preferences.enabledStyles = styles
    }

    func disableStyle(_ style: SummaryStyle) {
        var styles = preferences.enabledStyles
        styles.remove(style)
        // Ensure at least one style is always enabled
        if styles.isEmpty {
            styles.insert(.tldr)
        }
        preferences.enabledStyles = styles
    }

    func isStyleEnabled(_ style: SummaryStyle) -> Bool {
        preferences.enabledStyles.contains(style)
    }

    func setDefaultStyle(_ style: SummaryStyle) {
        // Ensure the default style is also enabled
        enableStyle(style)
        preferences.defaultStyle = style
    }

    // MARK: - Auto-Summarize

    var autoSummarize: Bool {
        preferences.autoSummarize
    }

    func setAutoSummarize(_ enabled: Bool) {
        preferences.autoSummarize = enabled
    }

    // MARK: - Feed Sort Order

    var feedSortOrder: FeedSortOrder {
        preferences.feedSortOrder
    }

    func setFeedSortOrder(_ order: FeedSortOrder) {
        preferences.feedSortOrder = order
    }

    // MARK: - Paper Retention

    var paperRetentionDays: Int {
        preferences.paperRetentionDays
    }

    func setPaperRetentionDays(_ days: Int) {
        preferences.paperRetentionDays = max(1, min(365, days))
    }

    // MARK: - Scroll Position & Tab Persistence

    var lastActiveTab: FeedTab {
        get { FeedTab(rawValue: preferences.lastActiveTab) ?? .latest }
        set { preferences.lastActiveTab = newValue.rawValue }
    }

    func savedScrollPosition(for tab: FeedTab) -> String? {
        switch tab {
        case .latest: return preferences.scrollPositionLatest
        case .trending: return preferences.scrollPositionTrending
        default: return nil
        }
    }

    func saveScrollPosition(_ id: String?, for tab: FeedTab) {
        switch tab {
        case .latest: preferences.scrollPositionLatest = id
        case .trending: preferences.scrollPositionTrending = id
        default: break
        }
    }

    // MARK: - Notifications

    var notificationsEnabled: Bool {
        preferences.notificationsEnabled
    }

    var dailyDigestEnabled: Bool {
        preferences.dailyDigestEnabled
    }

    var dailyDigestHour: Int {
        preferences.dailyDigestHour
    }

    var dailyDigestMinute: Int {
        preferences.dailyDigestMinute
    }

    var hasRequestedNotificationPermission: Bool {
        preferences.hasRequestedNotificationPermission
    }

    /// Enable or disable notifications. Handles OS permission request if needed.
    /// Returns true if notifications were successfully enabled.
    @discardableResult
    func setNotificationsEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            // Check current OS authorization
            let status = await NotificationManager.shared.authorizationStatus()

            if status == .denied {
                return false
            }

            if status == .notDetermined {
                preferences.hasRequestedNotificationPermission = true
                let granted = await NotificationManager.shared.requestPermission()
                if !granted {
                    return false
                }
            }

            preferences.notificationsEnabled = true
        } else {
            preferences.notificationsEnabled = false
        }

        NotificationManager.shared.rescheduleAll(preferences: preferences)
        return preferences.notificationsEnabled
    }

    func setDailyDigestEnabled(_ enabled: Bool) {
        preferences.dailyDigestEnabled = enabled
        NotificationManager.shared.rescheduleAll(preferences: preferences)
    }

    func setDailyDigestTime(hour: Int, minute: Int) {
        preferences.dailyDigestHour = max(0, min(23, hour))
        preferences.dailyDigestMinute = max(0, min(59, minute))
        NotificationManager.shared.rescheduleAll(preferences: preferences)
    }

    // MARK: - Background Task Notifications

    var topicNotificationsEnabled: Bool {
        preferences.topicNotificationsEnabled
    }

    var newFeedItemsNotificationEnabled: Bool {
        preferences.newFeedItemsNotificationEnabled
    }

    var lastKnownLatestPaperId: String? {
        preferences.lastKnownLatestPaperId
    }

    func setTopicNotificationsEnabled(_ enabled: Bool) {
        preferences.topicNotificationsEnabled = enabled
        NotificationManager.shared.rescheduleAll(preferences: preferences)
    }

    func setNewFeedItemsNotificationEnabled(_ enabled: Bool) {
        preferences.newFeedItemsNotificationEnabled = enabled
        NotificationManager.shared.rescheduleAll(preferences: preferences)
    }

    func setLastKnownLatestPaperId(_ id: String?) {
        preferences.lastKnownLatestPaperId = id
    }

    // MARK: - Reset

    func resetToDefaults() {
        preferences = .default
        NotificationManager.shared.cancelAll()
    }
}

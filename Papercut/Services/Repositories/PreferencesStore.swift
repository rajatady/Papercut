//
//  PreferencesStore.swift
//  Papercut
//

import Foundation
import Observation

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

    // MARK: - Reset

    func resetToDefaults() {
        preferences = .default
    }
}

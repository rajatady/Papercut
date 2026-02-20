//
//  UserPreferences.swift
//  Papercut
//

import Foundation

struct UserPreferences: Codable {
    var followedCategories: [String]
    var enabledSummaryStyles: [String]
    var defaultSummaryStyle: String
    var autoSummarize: Bool
    var feedSortOrder: FeedSortOrder
    var paperRetentionDays: Int
    var hasCompletedOnboarding: Bool
    var lastActiveTab: String
    var scrollPositionLatest: String?
    var scrollPositionTrending: String?

    init(
        followedCategories: [String] = [],
        enabledSummaryStyles: [String] = SummaryStyle.allCases.map { $0.rawValue },
        defaultSummaryStyle: String = SummaryStyle.tldr.rawValue,
        autoSummarize: Bool = true,
        feedSortOrder: FeedSortOrder = .newest,
        paperRetentionDays: Int = 30,
        hasCompletedOnboarding: Bool = false,
        lastActiveTab: String = "Latest",
        scrollPositionLatest: String? = nil,
        scrollPositionTrending: String? = nil
    ) {
        self.followedCategories = followedCategories
        self.enabledSummaryStyles = enabledSummaryStyles
        self.defaultSummaryStyle = defaultSummaryStyle
        self.autoSummarize = autoSummarize
        self.feedSortOrder = feedSortOrder
        self.paperRetentionDays = paperRetentionDays
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastActiveTab = lastActiveTab
        self.scrollPositionLatest = scrollPositionLatest
        self.scrollPositionTrending = scrollPositionTrending
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        followedCategories = try container.decodeIfPresent([String].self, forKey: .followedCategories) ?? []
        enabledSummaryStyles = try container.decodeIfPresent([String].self, forKey: .enabledSummaryStyles) ?? SummaryStyle.allCases.map { $0.rawValue }
        defaultSummaryStyle = try container.decodeIfPresent(String.self, forKey: .defaultSummaryStyle) ?? SummaryStyle.tldr.rawValue
        autoSummarize = try container.decodeIfPresent(Bool.self, forKey: .autoSummarize) ?? true
        feedSortOrder = try container.decodeIfPresent(FeedSortOrder.self, forKey: .feedSortOrder) ?? .newest
        paperRetentionDays = try container.decodeIfPresent(Int.self, forKey: .paperRetentionDays) ?? 30
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        lastActiveTab = try container.decodeIfPresent(String.self, forKey: .lastActiveTab) ?? "Latest"
        scrollPositionLatest = try container.decodeIfPresent(String.self, forKey: .scrollPositionLatest)
        scrollPositionTrending = try container.decodeIfPresent(String.self, forKey: .scrollPositionTrending)
    }

    // MARK: - Computed Properties

    var followedCategorySet: Set<String> {
        get { Set(followedCategories) }
        set { followedCategories = Array(newValue) }
    }

    var enabledStyles: Set<SummaryStyle> {
        get {
            Set(enabledSummaryStyles.compactMap { SummaryStyle(rawValue: $0) })
        }
        set {
            enabledSummaryStyles = newValue.map { $0.rawValue }
        }
    }

    var defaultStyle: SummaryStyle {
        get {
            SummaryStyle(rawValue: defaultSummaryStyle) ?? .tldr
        }
        set {
            defaultSummaryStyle = newValue.rawValue
        }
    }
}

// MARK: - Feed Sort Order
enum FeedSortOrder: String, Codable, CaseIterable, Identifiable {
    case newest = "newest"
    case oldest = "oldest"
    case relevance = "relevance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest:
            return "Newest First"
        case .oldest:
            return "Oldest First"
        case .relevance:
            return "Trending"
        }
    }

    var iconName: String {
        switch self {
        case .newest:
            return "clock.fill"
        case .oldest:
            return "clock.arrow.circlepath"
        case .relevance:
            return "flame.fill"
        }
    }
}

// MARK: - Default Preferences
extension UserPreferences {
    static var `default`: UserPreferences {
        UserPreferences()
    }
}

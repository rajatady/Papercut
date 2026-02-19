//
//  UserPreferencesTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct UserPreferencesTests {

    // MARK: - Default Init

    @Test func defaultInit_hasCorrectDefaults() {
        let prefs = UserPreferences()
        #expect(prefs.followedCategories.isEmpty)
        #expect(prefs.enabledSummaryStyles.count == SummaryStyle.allCases.count)
        #expect(prefs.defaultSummaryStyle == SummaryStyle.tldr.rawValue)
        #expect(prefs.autoSummarize == true)
        #expect(prefs.feedSortOrder == .newest)
        #expect(prefs.paperRetentionDays == 30)
        #expect(prefs.hasCompletedOnboarding == false)
    }

    // MARK: - Custom Init

    @Test func customInit_setsValues() {
        let prefs = UserPreferences(
            followedCategories: ["cs.AI"],
            autoSummarize: false,
            feedSortOrder: .relevance,
            paperRetentionDays: 60,
            hasCompletedOnboarding: true
        )
        #expect(prefs.followedCategories == ["cs.AI"])
        #expect(prefs.autoSummarize == false)
        #expect(prefs.feedSortOrder == .relevance)
        #expect(prefs.paperRetentionDays == 60)
        #expect(prefs.hasCompletedOnboarding == true)
    }

    // MARK: - Computed Properties

    @Test func followedCategorySet_convertsCorrectly() {
        var prefs = UserPreferences(followedCategories: ["cs.AI", "cs.LG", "cs.AI"])
        let set = prefs.followedCategorySet
        #expect(set.count == 2)
        #expect(set.contains("cs.AI"))
        #expect(set.contains("cs.LG"))
    }

    @Test func followedCategorySet_setterUpdatesArray() {
        var prefs = UserPreferences()
        prefs.followedCategorySet = Set(["cs.CV", "stat.ML"])
        #expect(prefs.followedCategories.count == 2)
    }

    @Test func enabledStyles_convertsCorrectly() {
        let prefs = UserPreferences()
        #expect(prefs.enabledStyles.count == SummaryStyle.allCases.count)
    }

    @Test func enabledStyles_setterUpdatesArray() {
        var prefs = UserPreferences()
        prefs.enabledStyles = Set([.tldr, .keyFindings])
        #expect(prefs.enabledSummaryStyles.count == 2)
    }

    @Test func enabledStyles_handlesInvalidRawValues() {
        let prefs = UserPreferences(enabledSummaryStyles: ["tldr", "invalidStyle", "keyFindings"])
        #expect(prefs.enabledStyles.count == 2)
    }

    @Test func defaultStyle_returnsCorrectStyle() {
        let prefs = UserPreferences(defaultSummaryStyle: "keyFindings")
        #expect(prefs.defaultStyle == .keyFindings)
    }

    @Test func defaultStyle_fallsBackToTldr() {
        let prefs = UserPreferences(defaultSummaryStyle: "nonexistent")
        #expect(prefs.defaultStyle == .tldr)
    }

    @Test func defaultStyle_setterUpdatesRawValue() {
        var prefs = UserPreferences()
        prefs.defaultStyle = .methodology
        #expect(prefs.defaultSummaryStyle == "methodology")
    }

    // MARK: - Static Default

    @Test func staticDefault_matchesDefaultInit() {
        let prefs = UserPreferences.default
        let manual = UserPreferences()
        #expect(prefs.hasCompletedOnboarding == manual.hasCompletedOnboarding)
        #expect(prefs.autoSummarize == manual.autoSummarize)
        #expect(prefs.paperRetentionDays == manual.paperRetentionDays)
    }

    // MARK: - Codable

    @Test func codable_roundTrip() throws {
        let original = UserPreferences(
            followedCategories: ["cs.AI", "cs.LG"],
            autoSummarize: false,
            feedSortOrder: .oldest,
            paperRetentionDays: 14,
            hasCompletedOnboarding: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded.followedCategories == original.followedCategories)
        #expect(decoded.autoSummarize == original.autoSummarize)
        #expect(decoded.feedSortOrder == original.feedSortOrder)
        #expect(decoded.paperRetentionDays == original.paperRetentionDays)
        #expect(decoded.hasCompletedOnboarding == original.hasCompletedOnboarding)
    }
}

// MARK: - FeedSortOrder Tests

@Suite(.serialized)
struct FeedSortOrderTests {

    @Test func allCases_containsThreeOrders() {
        #expect(FeedSortOrder.allCases.count == 3)
    }

    @Test func rawValues_correct() {
        #expect(FeedSortOrder.newest.rawValue == "newest")
        #expect(FeedSortOrder.oldest.rawValue == "oldest")
        #expect(FeedSortOrder.relevance.rawValue == "relevance")
    }

    @Test func id_matchesRawValue() {
        for order in FeedSortOrder.allCases {
            #expect(order.id == order.rawValue)
        }
    }

    @Test func displayName_nonEmpty() {
        for order in FeedSortOrder.allCases {
            #expect(!order.displayName.isEmpty)
        }
    }

    @Test func iconName_nonEmpty() {
        for order in FeedSortOrder.allCases {
            #expect(!order.iconName.isEmpty)
        }
    }

    @Test func codable_roundTrip() throws {
        for order in FeedSortOrder.allCases {
            let data = try JSONEncoder().encode(order)
            let decoded = try JSONDecoder().decode(FeedSortOrder.self, from: data)
            #expect(decoded == order)
        }
    }
}

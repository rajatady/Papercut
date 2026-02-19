//
//  PreferencesStoreTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct PreferencesStoreTests {

    // MARK: - Helpers

    @MainActor
    private func makeStore() -> PreferencesStore {
        let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        return PreferencesStore(userDefaults: defaults)
    }

    // MARK: - Initial State

    @MainActor
    @Test func init_defaultState() {
        let store = makeStore()
        #expect(store.hasCompletedOnboarding == false)
        #expect(store.followedCategories.isEmpty)
        #expect(store.enabledSummaryStyles.count == SummaryStyle.allCases.count)
        #expect(store.defaultSummaryStyle == .tldr)
        #expect(store.autoSummarize == true)
        #expect(store.feedSortOrder == .newest)
        #expect(store.paperRetentionDays == 30)
    }

    // MARK: - Onboarding

    @MainActor
    @Test func completeOnboarding_setsFlag() {
        let store = makeStore()
        #expect(store.hasCompletedOnboarding == false)
        store.completeOnboarding()
        #expect(store.hasCompletedOnboarding == true)
    }

    // MARK: - Categories

    @MainActor
    @Test func followCategory_addsCategory() {
        let store = makeStore()
        store.followCategory("cs.AI")
        #expect(store.followedCategories == ["cs.AI"])
        #expect(store.isFollowing("cs.AI") == true)
    }

    @MainActor
    @Test func followCategory_noDuplicates() {
        let store = makeStore()
        store.followCategory("cs.AI")
        store.followCategory("cs.AI")
        #expect(store.followedCategories.count == 1)
    }

    @MainActor
    @Test func unfollowCategory_removesCategory() {
        let store = makeStore()
        store.followCategory("cs.AI")
        store.followCategory("cs.LG")
        store.unfollowCategory("cs.AI")

        #expect(store.followedCategories == ["cs.LG"])
        #expect(store.isFollowing("cs.AI") == false)
    }

    @MainActor
    @Test func unfollowCategory_nonexistent_noOp() {
        let store = makeStore()
        store.unfollowCategory("cs.AI") // nothing to remove
        #expect(store.followedCategories.isEmpty)
    }

    @MainActor
    @Test func setFollowedCategories_replacesAll() {
        let store = makeStore()
        store.followCategory("cs.AI")
        store.setFollowedCategories(["stat.ML", "cs.CV"])

        #expect(store.followedCategories.count == 2)
        #expect(store.isFollowing("cs.AI") == false)
        #expect(store.isFollowing("stat.ML") == true)
    }

    // MARK: - Summary Styles

    @MainActor
    @Test func enableStyle_addsStyle() {
        let store = makeStore()
        // All enabled by default, disable one first
        store.disableStyle(.mathExplained)
        #expect(store.isStyleEnabled(.mathExplained) == false)

        store.enableStyle(.mathExplained)
        #expect(store.isStyleEnabled(.mathExplained) == true)
    }

    @MainActor
    @Test func disableStyle_removesStyle() {
        let store = makeStore()
        store.disableStyle(.codeExplained)
        #expect(store.isStyleEnabled(.codeExplained) == false)
    }

    @MainActor
    @Test func disableStyle_alwaysKeepsAtLeastOne() {
        let store = makeStore()
        // Disable all styles
        for style in SummaryStyle.allCases {
            store.disableStyle(style)
        }
        // Should still have at least .tldr
        #expect(store.enabledSummaryStyles.contains(.tldr))
        #expect(!store.enabledSummaryStyles.isEmpty)
    }

    @MainActor
    @Test func setDefaultStyle_alsoEnablesIt() {
        let store = makeStore()
        store.disableStyle(.implications)
        #expect(store.isStyleEnabled(.implications) == false)

        store.setDefaultStyle(.implications)
        #expect(store.defaultSummaryStyle == .implications)
        #expect(store.isStyleEnabled(.implications) == true)
    }

    // MARK: - Auto-Summarize

    @MainActor
    @Test func setAutoSummarize_toggles() {
        let store = makeStore()
        #expect(store.autoSummarize == true)

        store.setAutoSummarize(false)
        #expect(store.autoSummarize == false)

        store.setAutoSummarize(true)
        #expect(store.autoSummarize == true)
    }

    // MARK: - Feed Sort Order

    @MainActor
    @Test func setFeedSortOrder_updates() {
        let store = makeStore()
        store.setFeedSortOrder(.oldest)
        #expect(store.feedSortOrder == .oldest)

        store.setFeedSortOrder(.relevance)
        #expect(store.feedSortOrder == .relevance)
    }

    // MARK: - Paper Retention

    @MainActor
    @Test func setPaperRetentionDays_clampsToRange() {
        let store = makeStore()

        store.setPaperRetentionDays(0)
        #expect(store.paperRetentionDays == 1) // min clamped

        store.setPaperRetentionDays(500)
        #expect(store.paperRetentionDays == 365) // max clamped

        store.setPaperRetentionDays(60)
        #expect(store.paperRetentionDays == 60) // normal value
    }

    @MainActor
    @Test func setPaperRetentionDays_negativeClampsToMin() {
        let store = makeStore()
        store.setPaperRetentionDays(-10)
        #expect(store.paperRetentionDays == 1)
    }

    // MARK: - Reset

    @MainActor
    @Test func resetToDefaults_restoresAllDefaults() {
        let store = makeStore()

        // Modify everything
        store.completeOnboarding()
        store.followCategory("cs.AI")
        store.setAutoSummarize(false)
        store.setFeedSortOrder(.oldest)
        store.setPaperRetentionDays(7)

        // Reset
        store.resetToDefaults()

        #expect(store.hasCompletedOnboarding == false)
        #expect(store.followedCategories.isEmpty)
        #expect(store.autoSummarize == true)
        #expect(store.feedSortOrder == .newest)
        #expect(store.paperRetentionDays == 30)
    }

    // MARK: - Persistence

    @MainActor
    @Test func persistence_surviveReinitialization() {
        let defaults = UserDefaults(suiteName: "test_persist_\(UUID().uuidString)")!

        // Write
        let store1 = PreferencesStore(userDefaults: defaults)
        store1.followCategory("cs.AI")
        store1.completeOnboarding()
        store1.setAutoSummarize(false)

        // Re-read from same UserDefaults
        let store2 = PreferencesStore(userDefaults: defaults)
        #expect(store2.followedCategories == ["cs.AI"])
        #expect(store2.hasCompletedOnboarding == true)
        #expect(store2.autoSummarize == false)
    }
}

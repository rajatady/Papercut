//
//  TabStateMachineTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

// MARK: - Test Helpers

private func makePapers(count: Int, idPrefix: String = "paper") -> [Paper] {
    (0..<count).map { i in
        Paper(
            id: "\(idPrefix)_\(i)",
            title: "Paper \(i)",
            abstract: "Abstract \(i)",
            authors: [Author(name: "Author \(i)")],
            categories: ["cs.AI"],
            publishedDate: Date(),
            updatedDate: Date(),
            pdfURL: "https://arxiv.org/pdf/2401.\(String(format: "%05d", i))v1",
            abstractURL: "https://arxiv.org/abs/2401.\(String(format: "%05d", i))"
        )
    }
}

private func loadedState(
    paperCount: Int = 5,
    page: Int = 0,
    hasMore: Bool = true,
    fresh: Bool = true,
    scrollPosition: String? = nil
) -> TabState {
    let papers = makePapers(count: paperCount)
    let lastFetched: Date = fresh
        ? Date()
        : Date(timeIntervalSinceNow: -(TabState.staleThreshold + 60))
    return TabState(
        papers: papers,
        page: page,
        scrollPosition: scrollPosition,
        loadState: .loaded,
        hasMore: hasMore,
        lastFetchedAt: lastFetched,
        showNewPapersPill: false
    )
}

private func loadingState() -> TabState {
    TabState(
        papers: [],
        page: 0,
        scrollPosition: nil,
        loadState: .loading,
        hasMore: true,
        lastFetchedAt: nil,
        showNewPapersPill: false
    )
}

private func errorState(message: String = "Network error") -> TabState {
    TabState(
        papers: [],
        page: 0,
        scrollPosition: nil,
        loadState: .error(message),
        hasMore: true,
        lastFetchedAt: nil,
        showNewPapersPill: false
    )
}

private func refreshingState(paperCount: Int = 5, scrollPosition: String? = nil) -> TabState {
    let papers = makePapers(count: paperCount)
    return TabState(
        papers: papers,
        page: 0,
        scrollPosition: scrollPosition,
        loadState: .refreshing,
        hasMore: true,
        lastFetchedAt: Date(timeIntervalSinceNow: -(TabState.staleThreshold + 60)),
        showNewPapersPill: false
    )
}

private func loadingMoreState(paperCount: Int = 5, page: Int = 0) -> TabState {
    let papers = makePapers(count: paperCount)
    return TabState(
        papers: papers,
        page: page,
        scrollPosition: nil,
        loadState: .loadingMore,
        hasMore: true,
        lastFetchedAt: Date(),
        showNewPapersPill: false
    )
}

// MARK: - Latest Tab Tests

@Suite("Latest Tab Transitions")
struct LatestTabTests {

    // L1: .empty → tab becomes active → .loading + fetch page 0
    @Test func L1_empty_tabBecameActive_transitionsToLoading() {
        let state = TabState.initial
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(effects.contains(.fetch(page: 0, forceRefresh: false)))
    }

    // L2: .loading → fetch succeeds → .loaded
    @Test func L2_loading_fetchSucceeds_transitionsToLoaded() {
        let state = loadingState()
        let papers = makePapers(count: 5)
        let now = Date()
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: papers, hasMore: true),
            tab: .latest,
            now: now
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5)
        #expect(newState.page == 0)
        #expect(newState.hasMore == true)
        #expect(newState.lastFetchedAt == now)
        #expect(effects.contains(.queueSummaries))
    }

    // L3: .loading → fetch fails → .error
    @Test func L3_loading_fetchFails_transitionsToError() {
        let state = loadingState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .fetchFailed(error: "Network error"), tab: .latest
        )
        #expect(newState.loadState == .error("Network error"))
        #expect(newState.papers.isEmpty)
        #expect(!effects.contains(.queueSummaries))
    }

    // L4: .error → retry → .loading
    @Test func L4_error_retryTapped_transitionsToLoading() {
        let state = errorState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .retryTapped, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.fetch(page: 0, forceRefresh: false)))
    }

    // L5: .loaded, hasMore → loadMore → .loadingMore
    @Test func L5_loaded_loadMoreTriggered_hasMore_transitionsToLoadingMore() {
        let state = loadedState(paperCount: 5, page: 0, hasMore: true)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .loadMoreTriggered, tab: .latest
        )
        #expect(newState.loadState == .loadingMore)
        #expect(newState.papers.count == 5) // papers unchanged
        #expect(effects.contains(.fetch(page: 1, forceRefresh: false)))
    }

    // L6: .loaded, noMore → loadMore → stays .loaded
    @Test func L6_loaded_loadMoreTriggered_noMore_staysLoaded() {
        let state = loadedState(paperCount: 5, page: 0, hasMore: false)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .loadMoreTriggered, tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5)
        #expect(effects.isEmpty || effects == [.none])
    }

    // L7: .loadingMore → fetch succeeds → .loaded, papers appended
    @Test func L7_loadingMore_fetchSucceeds_appendsPapers_transitionsToLoaded() {
        let state = loadingMoreState(paperCount: 5, page: 0)
        let newPapers = makePapers(count: 3, idPrefix: "new")
        let now = Date()
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: newPapers, hasMore: true),
            tab: .latest,
            now: now
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 8) // 5 existing + 3 new
        #expect(newState.page == 1) // incremented
        #expect(newState.hasMore == true)
        #expect(newState.lastFetchedAt == now)
        #expect(effects.contains(.queueSummaries))
    }

    // L8: .loadingMore → fetch fails → .loaded + toast
    @Test func L8_loadingMore_fetchFails_showsToast_staysLoaded() {
        let state = loadingMoreState(paperCount: 5, page: 0)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .fetchFailed(error: "Timeout"), tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5) // unchanged
        #expect(newState.page == 0) // not incremented
        #expect(effects.contains(.showToast("Couldn't load more papers")))
    }

    // L9: .loaded, fresh → tab becomes active → no fetch, restore scroll
    @Test func L9_loaded_fresh_tabBecameActive_noFetch_restoresScroll() {
        let state = loadedState(paperCount: 5, fresh: true, scrollPosition: "paper_2")
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5)
        #expect(effects.contains(.restoreScrollPosition))
        #expect(!effects.contains(where: { if case .fetch = $0 { return true }; return false }))
    }

    // L10: .loaded, stale → tab becomes active → .refreshing + fetch
    @Test func L10_loaded_stale_tabBecameActive_transitionsToRefreshing() {
        let state = loadedState(paperCount: 5, fresh: false, scrollPosition: "paper_3")
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .latest
        )
        #expect(newState.loadState == .refreshing)
        #expect(newState.papers.count == 5) // still visible
        #expect(effects.contains(.restoreScrollPosition))
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
    }

    // L11: .refreshing → fetch succeeds → .loaded, data replaced
    @Test func L11_refreshing_fetchSucceeds_replacesData() {
        let state = refreshingState(paperCount: 5)
        let freshPapers = makePapers(count: 8, idPrefix: "fresh")
        let now = Date()
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: freshPapers, hasMore: true),
            tab: .latest,
            now: now
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 8)
        #expect(newState.papers[0].id == "fresh_0")
        #expect(newState.page == 0)
        #expect(newState.lastFetchedAt == now)
        #expect(effects.contains(.queueSummaries))
    }

    // L12: .refreshing → fetch fails → .loaded + toast, keep old data
    @Test func L12_refreshing_fetchFails_keepsOldData_showsToast() {
        let state = refreshingState(paperCount: 5)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .fetchFailed(error: "Server error"), tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5) // unchanged
        #expect(effects.contains(.showToast("Couldn't refresh — showing cached papers")))
    }

    // L13: .loaded → pull to refresh → .refreshing
    @Test func L13_loaded_pullToRefresh_transitionsToRefreshing() {
        let state = loadedState(paperCount: 5)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .pullToRefresh, tab: .latest
        )
        #expect(newState.loadState == .refreshing)
        #expect(newState.papers.count == 5) // still visible
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
    }

    // L14: .loaded → categories changed → .loading, clear papers
    @Test func L14_loaded_categoriesChanged_clearsAndReloads() {
        let state = loadedState(paperCount: 5)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(newState.page == 0)
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
        #expect(effects.contains(.cancelSummaries))
    }

    // L15: .loadingMore → tab becomes inactive → .loaded, cancel, save scroll
    @Test func L15_loadingMore_tabBecameInactive_cancelsAndKeepsPapers() {
        let state = loadingMoreState(paperCount: 5, page: 0)
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .tabBecameInactive(saveScrollPosition: "paper_3"),
            tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5) // preserved
        #expect(newState.scrollPosition == "paper_3")
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.saveScrollPosition("paper_3")))
    }

    // L16: .loading → tab becomes inactive → .empty, cancel
    @Test func L16_loading_tabBecameInactive_transitionsToEmpty() {
        let state = loadingState()
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .tabBecameInactive(saveScrollPosition: nil),
            tab: .latest
        )
        #expect(newState.loadState == .empty)
        #expect(newState.papers.isEmpty)
        #expect(effects.contains(.cancelFetch))
    }

    // L17: .refreshing → tab becomes inactive → .loaded, cancel, keep data
    @Test func L17_refreshing_tabBecameInactive_cancelsKeepsData() {
        let state = refreshingState(paperCount: 5)
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .tabBecameInactive(saveScrollPosition: "paper_2"),
            tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5) // preserved
        #expect(newState.scrollPosition == "paper_2")
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.saveScrollPosition("paper_2")))
    }

    // L18: .error → tab becomes active → .loading (auto-retry)
    @Test func L18_error_tabBecameActive_autoRetries() {
        let state = errorState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.fetch(page: 0, forceRefresh: false)))
    }

    // L19: .loading → categories changed → restart with new categories
    @Test func L19_loading_categoriesChanged_restartsWithNewCategories() {
        let state = loadingState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(newState.page == 0)
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
    }

    // L20: .loadingMore → categories changed → .loading, clear, fetch
    @Test func L20_loadingMore_categoriesChanged_clearsAndReloads() {
        let state = loadingMoreState(paperCount: 5, page: 1)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(newState.page == 0)
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
        #expect(effects.contains(.cancelSummaries))
    }

    // L21: .refreshing → categories changed → .loading, clear, fetch
    @Test func L21_refreshing_categoriesChanged_clearsAndReloads() {
        let state = refreshingState(paperCount: 5)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(newState.page == 0)
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
        #expect(effects.contains(.cancelSummaries))
    }

    // L22: .error → categories changed → .loading
    @Test func L22_error_categoriesChanged_transitionsToLoading() {
        let state = errorState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(newState.page == 0)
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
    }

    // L: fetch succeeds with zero papers → .loaded (empty state)
    @Test func L_fetchSucceeds_zeroPapers_staysLoadedShowsEmpty() {
        let state = loadingState()
        let now = Date()
        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: [], hasMore: false),
            tab: .latest,
            now: now
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.isEmpty)
        #expect(newState.hasMore == false)
        #expect(newState.lastFetchedAt == now)
    }

    // L: .loadingMore → fetch succeeds with duplicate IDs → dedup
    @Test func L_loadingMore_appendDeduplicatesByPaperId() {
        // Existing papers: paper_0, paper_1, paper_2
        let state = loadingMoreState(paperCount: 3, page: 0)
        // New papers include a duplicate (paper_1) and two new ones
        let existingDupe = makePapers(count: 1, idPrefix: "paper") // paper_0
        let newUnique = makePapers(count: 2, idPrefix: "unique")   // unique_0, unique_1
        let newPapers = existingDupe + newUnique

        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: newPapers, hasMore: true),
            tab: .latest
        )
        // Should have 3 existing + 2 new unique = 5 (not 6)
        #expect(newState.papers.count == 5)
        let ids = newState.papers.map(\.id)
        #expect(ids.contains("unique_0"))
        #expect(ids.contains("unique_1"))
    }

    // L: .error → pull to refresh → .loading
    @Test func L_error_pullToRefresh_transitionsToLoading() {
        let state = errorState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .pullToRefresh, tab: .latest
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
    }

    // L: app foregrounded, stale → .refreshing
    @Test func L_appForegrounded_stale_transitionsToRefreshing() {
        let state = loadedState(paperCount: 5, fresh: false)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .appForegrounded, tab: .latest
        )
        #expect(newState.loadState == .refreshing)
        #expect(newState.papers.count == 5)
        #expect(effects.contains(.fetch(page: 0, forceRefresh: true)))
    }

    // L: app foregrounded, fresh → no-op
    @Test func L_appForegrounded_fresh_noOp() {
        let state = loadedState(paperCount: 5, fresh: true)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .appForegrounded, tab: .latest
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5)
        #expect(!effects.contains(where: { if case .fetch = $0 { return true }; return false }))
    }
}

// MARK: - Trending Tab Tests

@Suite("Trending Tab Transitions")
struct TrendingTabTests {

    // T1: .empty → tab becomes active → .loading
    @Test func T1_empty_tabBecameActive_transitionsToLoading() {
        let state = TabState.initial
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .trending
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.fetchTrending))
    }

    // T2: .loading → fetch succeeds → .loaded, hasMore always false
    @Test func T2_loading_fetchSucceeds_transitionsToLoaded() {
        let state = loadingState()
        let papers = makePapers(count: 10)
        let now = Date()
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: papers, hasMore: true), // even if API says true
            tab: .trending,
            now: now
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 10)
        #expect(newState.hasMore == false) // always false for trending
        #expect(newState.lastFetchedAt == now)
        #expect(effects.contains(.queueSummaries))
    }

    // T3: .loading → fetch fails → .error
    @Test func T3_loading_fetchFails_transitionsToError() {
        let state = loadingState()
        let (newState, _) = TabStateMachine.transition(
            state: state, event: .fetchFailed(error: "API error"), tab: .trending
        )
        #expect(newState.loadState == .error("API error"))
        #expect(newState.papers.isEmpty)
    }

    // T4: .error → retry → .loading
    @Test func T4_error_retryTapped_transitionsToLoading() {
        let state = errorState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .retryTapped, tab: .trending
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.fetchTrending))
    }

    // T5: .loaded → loadMore → no-op (trending doesn't paginate)
    @Test func T5_loaded_loadMoreTriggered_noPagination() {
        let state = loadedState(paperCount: 10, hasMore: false)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .loadMoreTriggered, tab: .trending
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 10)
        #expect(!effects.contains(where: { if case .fetch = $0 { return true }; return false }))
        #expect(!effects.contains(.fetchTrending))
    }

    // T6: .loaded, fresh → tab becomes active → no fetch
    @Test func T6_loaded_fresh_tabBecameActive_noFetch() {
        let state = loadedState(paperCount: 10, fresh: true, scrollPosition: "paper_5")
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .trending
        )
        #expect(newState.loadState == .loaded)
        #expect(effects.contains(.restoreScrollPosition))
        #expect(!effects.contains(.fetchTrending))
    }

    // T7: .loaded, stale → tab becomes active → .refreshing
    @Test func T7_loaded_stale_tabBecameActive_transitionsToRefreshing() {
        let state = loadedState(paperCount: 10, fresh: false, scrollPosition: "paper_5")
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .trending
        )
        #expect(newState.loadState == .refreshing)
        #expect(newState.papers.count == 10) // still visible
        #expect(effects.contains(.restoreScrollPosition))
        #expect(effects.contains(.fetchTrending))
    }

    // T8: .refreshing → fetch succeeds → .loaded
    @Test func T8_refreshing_fetchSucceeds_replacesData() {
        let state = refreshingState(paperCount: 5)
        let freshPapers = makePapers(count: 12, idPrefix: "trending")
        let now = Date()
        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: freshPapers, hasMore: false),
            tab: .trending,
            now: now
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 12)
        #expect(newState.hasMore == false)
        #expect(newState.lastFetchedAt == now)
    }

    // T9: .refreshing → fetch fails → .loaded + toast
    @Test func T9_refreshing_fetchFails_keepsOldData() {
        let state = refreshingState(paperCount: 5)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .fetchFailed(error: "Timeout"), tab: .trending
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 5)
        #expect(effects.contains(.showToast("Couldn't refresh — showing cached papers")))
    }

    // T10: .loaded → pull to refresh → .refreshing
    @Test func T10_loaded_pullToRefresh_transitionsToRefreshing() {
        let state = loadedState(paperCount: 10)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .pullToRefresh, tab: .trending
        )
        #expect(newState.loadState == .refreshing)
        #expect(newState.papers.count == 10)
        #expect(effects.contains(.fetchTrending))
    }

    // T11: .loaded → categories changed → .loading, clear
    @Test func T11_loaded_categoriesChanged_clearsAndReloads() {
        let state = loadedState(paperCount: 10)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .trending
        )
        #expect(newState.loadState == .loading)
        #expect(newState.papers.isEmpty)
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.fetchTrending))
        #expect(effects.contains(.cancelSummaries))
    }

    // T: hasMore is always false after fetch
    @Test func T_hasMore_alwaysFalse() {
        let state = loadingState()
        let papers = makePapers(count: 50)
        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: papers, hasMore: true), // API might say true
            tab: .trending
        )
        #expect(newState.hasMore == false) // forced to false
    }

    // T: .error → tab becomes active → auto-retry
    @Test func T_error_tabBecameActive_autoRetries() {
        let state = errorState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .trending
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.fetchTrending))
    }

    // T: .loading → categories changed → restart
    @Test func T_loading_categoriesChanged_restartsWithNewCategories() {
        let state = loadingState()
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .trending
        )
        #expect(newState.loadState == .loading)
        #expect(effects.contains(.cancelFetch))
        #expect(effects.contains(.fetchTrending))
    }
}

// MARK: - Saved Tab Tests

@Suite("Saved Tab Transitions")
struct SavedTabTests {

    // S1: .empty → tab becomes active → .loaded (query SwiftData)
    @Test func S1_empty_tabBecameActive_queriesSwiftData() {
        let state = TabState.initial
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .saved
        )
        #expect(newState.loadState == .loaded)
        #expect(effects.contains(.querySwiftData))
        // No network fetch
        #expect(!effects.contains(where: { if case .fetch = $0 { return true }; return false }))
        #expect(!effects.contains(.fetchTrending))
    }

    // S2: .loaded → tab becomes active → re-query
    @Test func S2_loaded_tabBecameActive_requeriesSwiftData() {
        let state = loadedState(paperCount: 3, fresh: true)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .saved
        )
        #expect(newState.loadState == .loaded)
        #expect(effects.contains(.querySwiftData))
        #expect(effects.contains(.restoreScrollPosition))
    }

    // S3: paper bookmarked → appears
    @Test func S3_paperBookmarked_appearsInList() {
        let state = loadedState(paperCount: 2)
        let (_, effects) = TabStateMachine.transition(
            state: state,
            event: .paperBookmarked(paperId: "new_paper"),
            tab: .saved
        )
        // Side effect should re-query SwiftData to get updated list
        #expect(effects.contains(.querySwiftData))
    }

    // S4: paper unbookmarked → disappears
    @Test func S4_paperUnbookmarked_disappearsFromList() {
        let state = loadedState(paperCount: 3)
        let (_, effects) = TabStateMachine.transition(
            state: state,
            event: .paperUnbookmarked(paperId: "paper_1"),
            tab: .saved
        )
        #expect(effects.contains(.querySwiftData))
    }

    // S5: loadMore → no-op
    @Test func S5_loaded_loadMoreTriggered_noOp() {
        let state = loadedState(paperCount: 5, hasMore: false)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .loadMoreTriggered, tab: .saved
        )
        #expect(newState.loadState == .loaded)
        #expect(!effects.contains(where: { if case .fetch = $0 { return true }; return false }))
    }

    // S6: empty result → still .loaded (empty state UI)
    @Test func S6_empty_tabBecameActive_emptyResult_showsEmptyState() {
        let state = TabState.initial
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .tabBecameActive, tab: .saved
        )
        #expect(newState.loadState == .loaded)
        #expect(effects.contains(.querySwiftData))
    }

    // S: saved tab NEVER makes a network request
    @Test func S_neverMakesNetworkRequest() {
        let events: [FeedEvent] = [
            .tabBecameActive,
            .pullToRefresh,
            .categoriesChanged,
            .appForegrounded,
            .retryTapped,
            .loadMoreTriggered,
        ]
        for event in events {
            let state = loadedState(paperCount: 3)
            let (_, effects) = TabStateMachine.transition(
                state: state, event: event, tab: .saved
            )
            let hasNetworkEffect = effects.contains(where: {
                switch $0 {
                case .fetch, .fetchTrending: return true
                default: return false
                }
            })
            #expect(!hasNetworkEffect, "Saved tab made network request for event: \(event)")
        }
    }

    // S: categories changed → no-op for saved tab
    @Test func S_categoriesChanged_noOp() {
        let state = loadedState(paperCount: 3)
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .saved
        )
        #expect(newState.loadState == .loaded)
        #expect(newState.papers.count == 3) // unchanged
        #expect(!effects.contains(.cancelFetch))
    }

    // S5 (fix): fetchSucceeded → papers stored in state
    @Test func S5_fetchSucceeded_storesPapers() {
        let state = TabState.initial
        let papers = makePapers(count: 3)
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: papers, hasMore: false),
            tab: .saved
        )
        #expect(newState.papers.count == 3)
        #expect(newState.loadState == .loaded)
        #expect(effects.contains(.queueSummaries))
    }

    // fetchSucceeded with empty papers → no queueSummaries
    @Test func S_fetchSucceeded_emptyPapers_noQueueSummaries() {
        let state = TabState.initial
        let (newState, effects) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: [], hasMore: false),
            tab: .saved
        )
        #expect(newState.papers.isEmpty)
        #expect(newState.loadState == .loaded)
        #expect(!effects.contains(.queueSummaries))
    }
}

// MARK: - New Papers Pill Tests

@Suite("New Papers Pill")
struct NewPapersPillTests {

    // Pill shown when refresh succeeds and user scrolled deep
    @Test func newPapersPill_shown_whenRefreshSucceeds_andUserScrolledDeep() {
        // User is viewing paper_3 (deep in the list)
        let state = refreshingState(paperCount: 5, scrollPosition: "paper_3")
        let freshPapers = makePapers(count: 8, idPrefix: "fresh")
        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: freshPapers, hasMore: true),
            tab: .latest
        )
        #expect(newState.showNewPapersPill == true)
    }

    // Pill NOT shown when user is at top
    @Test func newPapersPill_notShown_whenUserAtTop() {
        // User is at the very first paper or no scroll position
        let state = refreshingState(paperCount: 5, scrollPosition: nil)
        let freshPapers = makePapers(count: 8, idPrefix: "fresh")
        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: freshPapers, hasMore: true),
            tab: .latest
        )
        #expect(newState.showNewPapersPill == false)
    }

    // Pill tapped → scroll to top, dismiss
    @Test func newPapersPill_tapped_scrollsToTop_dismissesPill() {
        var state = loadedState(paperCount: 5, scrollPosition: "paper_3")
        state.showNewPapersPill = true
        let (newState, effects) = TabStateMachine.transition(
            state: state, event: .newPapersPillTapped, tab: .latest
        )
        #expect(newState.showNewPapersPill == false)
        #expect(effects.contains(.scrollToTop))
    }

    // Pill dismissed explicitly
    @Test func newPapersPill_dismissed() {
        var state = loadedState(paperCount: 5)
        state.showNewPapersPill = true
        let (newState, _) = TabStateMachine.transition(
            state: state, event: .newPapersPillDismissed, tab: .latest
        )
        #expect(newState.showNewPapersPill == false)
    }
}

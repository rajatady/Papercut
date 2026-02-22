//
//  FeedStateMachineInvariantTests.swift
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

// MARK: - Cross-Tab Invariant Tests

@Suite("Cross-Tab Invariants")
struct FeedStateMachineInvariantTests {

    // C1: Switching tabs never clears another tab's papers
    @Test func C1_switchTab_neverClearsOtherTabPapers() {
        // Simulate: Latest has 5 papers, user switches to Trending
        var latestState = loadedState(paperCount: 5, scrollPosition: "paper_2")
        var trendingState = TabState.initial

        // Step 1: Latest becomes inactive
        let (newLatest, _) = TabStateMachine.transition(
            state: latestState,
            event: .tabBecameInactive(saveScrollPosition: "paper_2"),
            tab: .latest
        )
        latestState = newLatest

        // Step 2: Trending becomes active
        let (newTrending, _) = TabStateMachine.transition(
            state: trendingState,
            event: .tabBecameActive,
            tab: .trending
        )
        trendingState = newTrending

        // Invariant: Latest's papers untouched
        #expect(latestState.papers.count == 5)
        #expect(latestState.scrollPosition == "paper_2")
    }

    // C2: Switching tabs never triggers fetch on the leaving tab
    @Test func C2_switchTab_neverFetchesOnLeavingTab() {
        let latestState = loadedState(paperCount: 5)

        let (_, effects) = TabStateMachine.transition(
            state: latestState,
            event: .tabBecameInactive(saveScrollPosition: "paper_0"),
            tab: .latest
        )

        let hasFetchEffect = effects.contains(where: {
            switch $0 {
            case .fetch, .fetchTrending: return true
            default: return false
            }
        })
        #expect(!hasFetchEffect)
    }

    // C3: Only the active tab can have .loading or .loadingMore
    // (Verified by: inactive transitions always resolve to .loaded or .empty)
    @Test func C3_onlyActiveTabCanBeLoadingOrLoadingMore() {
        // .loading → inactive → .empty
        let loadingState = TabState(
            papers: [], page: 0, scrollPosition: nil,
            loadState: .loading, hasMore: true, lastFetchedAt: nil, showNewPapersPill: false
        )
        let (afterLoading, _) = TabStateMachine.transition(
            state: loadingState,
            event: .tabBecameInactive(saveScrollPosition: nil),
            tab: .latest
        )
        #expect(afterLoading.loadState != .loading)
        #expect(afterLoading.loadState != .loadingMore)

        // .loadingMore → inactive → .loaded
        let loadingMoreState = TabState(
            papers: makePapers(count: 5), page: 0, scrollPosition: nil,
            loadState: .loadingMore, hasMore: true, lastFetchedAt: Date(), showNewPapersPill: false
        )
        let (afterLoadingMore, _) = TabStateMachine.transition(
            state: loadingMoreState,
            event: .tabBecameInactive(saveScrollPosition: nil),
            tab: .latest
        )
        #expect(afterLoadingMore.loadState != .loading)
        #expect(afterLoadingMore.loadState != .loadingMore)

        // .refreshing → inactive → .loaded
        let refreshingState = TabState(
            papers: makePapers(count: 5), page: 0, scrollPosition: nil,
            loadState: .refreshing, hasMore: true,
            lastFetchedAt: Date(timeIntervalSinceNow: -7200), showNewPapersPill: false
        )
        let (afterRefreshing, _) = TabStateMachine.transition(
            state: refreshingState,
            event: .tabBecameInactive(saveScrollPosition: nil),
            tab: .latest
        )
        #expect(afterRefreshing.loadState != .loading)
        #expect(afterRefreshing.loadState != .loadingMore)
        #expect(afterRefreshing.loadState != .refreshing)
    }

    // C4: scrollPosition is saved before any tab switch
    @Test func C4_scrollPositionSavedBeforeTabSwitch() {
        let latestState = loadedState(paperCount: 5)

        let (newState, effects) = TabStateMachine.transition(
            state: latestState,
            event: .tabBecameInactive(saveScrollPosition: "paper_3"),
            tab: .latest
        )

        #expect(newState.scrollPosition == "paper_3")
        #expect(effects.contains(.saveScrollPosition("paper_3")))
    }

    // C5: Cancel fires before new fetch in tab switch sequence
    @Test func C5_cancelBeforeFetchOrdering() {
        // When categories change, cancel should come before fetch
        let state = loadedState(paperCount: 5)
        let (_, effects) = TabStateMachine.transition(
            state: state, event: .categoriesChanged, tab: .latest
        )

        let cancelIndex = effects.firstIndex(of: .cancelFetch)
        let fetchIndex = effects.firstIndex(where: { if case .fetch = $0 { return true }; return false })

        #expect(cancelIndex != nil)
        #expect(fetchIndex != nil)
        if let c = cancelIndex, let f = fetchIndex {
            #expect(c < f, "cancelFetch must come before fetch")
        }
    }

    // C6: .refreshing never blanks screen
    @Test func C6_refreshingNeverBlanksScreen() {
        let state = TabState(
            papers: makePapers(count: 5), page: 0, scrollPosition: nil,
            loadState: .refreshing, hasMore: true,
            lastFetchedAt: Date(timeIntervalSinceNow: -7200), showNewPapersPill: false
        )

        // On success: still has papers
        let freshPapers = makePapers(count: 3, idPrefix: "fresh")
        let (successState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: freshPapers, hasMore: true),
            tab: .latest
        )
        #expect(!successState.papers.isEmpty)

        // On failure: still has papers
        let (failState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchFailed(error: "Oops"),
            tab: .latest
        )
        #expect(!failState.papers.isEmpty)
        #expect(failState.papers.count == 5) // original papers preserved
    }

    // C7: State is per-tab (verified by operating on independent states)
    @Test func C7_generationIsPerTab() {
        // Latest loads, Trending loads independently
        let latestInitial = TabState.initial
        let trendingInitial = TabState.initial

        let (latestLoading, _) = TabStateMachine.transition(
            state: latestInitial, event: .tabBecameActive, tab: .latest
        )
        let (trendingLoading, _) = TabStateMachine.transition(
            state: trendingInitial, event: .tabBecameActive, tab: .trending
        )

        // Each has its own state — latest fetches page, trending fetches trending
        #expect(latestLoading.loadState == .loading)
        #expect(trendingLoading.loadState == .loading)
        // They're independent structs — mutating one doesn't affect the other
    }

    // C8: Trending hasMore always false
    @Test func C8_trendingHasMoreAlwaysFalse() {
        let state = TabState(
            papers: [], page: 0, scrollPosition: nil,
            loadState: .loading, hasMore: true, lastFetchedAt: nil, showNewPapersPill: false
        )
        let papers = makePapers(count: 50)

        // Even if API says hasMore = true
        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: papers, hasMore: true),
            tab: .trending
        )
        #expect(newState.hasMore == false)
    }

    // C9: Saved and Topics tabs never make network requests
    @Test func C9_savedAndTopicsNeverMakeNetworkRequests() {
        let allEvents: [FeedEvent] = [
            .tabBecameActive,
            .tabBecameInactive(saveScrollPosition: nil),
            .fetchSucceeded(papers: [], hasMore: false),
            .fetchFailed(error: "err"),
            .loadMoreTriggered,
            .pullToRefresh,
            .retryTapped,
            .categoriesChanged,
            .appForegrounded,
            .paperBookmarked(paperId: "p1"),
            .paperUnbookmarked(paperId: "p1"),
        ]

        for tab: FeedTab in [.saved, .topics] {
            for event in allEvents {
                let state = loadedState(paperCount: 3)
                let (_, effects) = TabStateMachine.transition(
                    state: state, event: event, tab: tab
                )
                let hasNetworkEffect = effects.contains(where: {
                    switch $0 {
                    case .fetch, .fetchTrending: return true
                    default: return false
                    }
                })
                #expect(!hasNetworkEffect, "\(tab) tab made network request for \(event)")
            }
        }
    }

    // C10: Categories change resets Latest and Trending, not Saved
    @Test func C10_categoriesChangeResetsLatestAndTrending_notSaved() {
        let latestState = loadedState(paperCount: 5)
        let trendingState = loadedState(paperCount: 10)
        let savedState = loadedState(paperCount: 3)

        let (newLatest, _) = TabStateMachine.transition(
            state: latestState, event: .categoriesChanged, tab: .latest
        )
        let (newTrending, _) = TabStateMachine.transition(
            state: trendingState, event: .categoriesChanged, tab: .trending
        )
        let (newSaved, _) = TabStateMachine.transition(
            state: savedState, event: .categoriesChanged, tab: .saved
        )

        // Latest and Trending cleared
        #expect(newLatest.papers.isEmpty)
        #expect(newLatest.loadState == .loading)
        #expect(newTrending.papers.isEmpty)
        #expect(newTrending.loadState == .loading)

        // Saved unaffected
        #expect(newSaved.papers.count == 3)
        #expect(newSaved.loadState == .loaded)
    }

    // C11: No blank screen if previously had data (except categoriesChanged which is intentional)
    @Test func C11_noBlankScreenIfPreviouslyHadData() {
        let stateWithPapers = loadedState(paperCount: 5, fresh: false)

        // Pull to refresh: papers stay
        let (afterRefresh, _) = TabStateMachine.transition(
            state: stateWithPapers, event: .pullToRefresh, tab: .latest
        )
        #expect(!afterRefresh.papers.isEmpty)

        // Tab becomes active (stale): papers stay
        let (afterActivate, _) = TabStateMachine.transition(
            state: stateWithPapers, event: .tabBecameActive, tab: .latest
        )
        #expect(!afterActivate.papers.isEmpty)

        // App foregrounded (stale): papers stay
        let (afterForeground, _) = TabStateMachine.transition(
            state: stateWithPapers, event: .appForegrounded, tab: .latest
        )
        #expect(!afterForeground.papers.isEmpty)
    }

    // C12: Error + tab reactivation → auto-retry
    @Test func C12_error_tabReactivation_autoRetries() {
        let errorState = TabState(
            papers: [], page: 0, scrollPosition: nil,
            loadState: .error("Failed"), hasMore: true, lastFetchedAt: nil, showNewPapersPill: false
        )

        // Latest
        let (latestResult, latestEffects) = TabStateMachine.transition(
            state: errorState, event: .tabBecameActive, tab: .latest
        )
        #expect(latestResult.loadState == .loading)
        #expect(latestEffects.contains(.fetch(page: 0, forceRefresh: false)))

        // Trending
        let (trendingResult, trendingEffects) = TabStateMachine.transition(
            state: errorState, event: .tabBecameActive, tab: .trending
        )
        #expect(trendingResult.loadState == .loading)
        #expect(trendingEffects.contains(.fetchTrending))
    }

    // C13: Categories changed from ANY state is handled (not just .loaded)
    @Test func C13_categoriesChanged_anyState_handledCorrectly() {
        let states: [(String, TabState)] = [
            ("empty", TabState.initial),
            ("loading", TabState(papers: [], page: 0, scrollPosition: nil,
                                 loadState: .loading, hasMore: true, lastFetchedAt: nil, showNewPapersPill: false)),
            ("loaded", loadedState(paperCount: 5)),
            ("loadingMore", TabState(papers: makePapers(count: 5), page: 1, scrollPosition: nil,
                                     loadState: .loadingMore, hasMore: true, lastFetchedAt: Date(), showNewPapersPill: false)),
            ("refreshing", TabState(papers: makePapers(count: 5), page: 0, scrollPosition: nil,
                                    loadState: .refreshing, hasMore: true,
                                    lastFetchedAt: Date(timeIntervalSinceNow: -7200), showNewPapersPill: false)),
            ("error", TabState(papers: [], page: 0, scrollPosition: nil,
                               loadState: .error("Err"), hasMore: true, lastFetchedAt: nil, showNewPapersPill: false)),
        ]

        for (name, state) in states {
            let (newState, effects) = TabStateMachine.transition(
                state: state, event: .categoriesChanged, tab: .latest
            )
            #expect(newState.loadState == .loading, "From \(name): expected .loading after categoriesChanged")
            #expect(newState.papers.isEmpty, "From \(name): expected empty papers after categoriesChanged")
            #expect(effects.contains(.fetch(page: 0, forceRefresh: true)),
                    "From \(name): expected fetch after categoriesChanged")
        }
    }

    // C14: Deduplication on append
    @Test func C14_deduplicationOnAppend() {
        let existingPapers = makePapers(count: 3, idPrefix: "paper")
        let state = TabState(
            papers: existingPapers, page: 0, scrollPosition: nil,
            loadState: .loadingMore, hasMore: true, lastFetchedAt: Date(), showNewPapersPill: false
        )

        // New batch contains paper_2 (duplicate) + two new
        let duplicate = makePapers(count: 1, idPrefix: "paper") // paper_0
        let unique = makePapers(count: 2, idPrefix: "new")       // new_0, new_1
        let newBatch = duplicate + unique // 3 papers, 1 is duplicate

        let (newState, _) = TabStateMachine.transition(
            state: state,
            event: .fetchSucceeded(papers: newBatch, hasMore: true),
            tab: .latest
        )

        // 3 existing + 2 unique = 5, not 6
        #expect(newState.papers.count == 5)
        let ids = Set(newState.papers.map(\.id))
        #expect(ids.count == 5, "All paper IDs should be unique")
    }
}

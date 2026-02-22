//
//  TabStateMachine.swift
//  Papercut
//

import Foundation

enum TabStateMachine {

    /// Pure state transition function.
    /// Given current state, an event, and which tab we're on, returns
    /// the new state and a list of side effects to execute.
    static func transition(
        state: TabState,
        event: FeedEvent,
        tab: FeedTab,
        now: Date = Date()
    ) -> (TabState, [FeedSideEffect]) {
        switch tab {
        case .saved:
            return transitionSaved(state: state, event: event, now: now)
        case .latest:
            return transitionLatest(state: state, event: event, now: now)
        case .trending:
            return transitionTrending(state: state, event: event, now: now)
        case .topics:
            return transitionTopics(state: state, event: event, now: now)
        }
    }

    // MARK: - Latest Tab

    private static func transitionLatest(
        state: TabState,
        event: FeedEvent,
        now: Date
    ) -> (TabState, [FeedSideEffect]) {
        var newState = state
        var effects: [FeedSideEffect] = []

        switch (state.loadState, event) {

        // L1: .empty → tabBecameActive → .loading + fetch + restore scroll
        case (.empty, .tabBecameActive):
            newState.loadState = .loading
            effects.append(.restoreScrollPosition)
            effects.append(.fetch(page: 0, forceRefresh: false))

        // L18: .error → tabBecameActive → .loading (auto-retry)
        case (.error, .tabBecameActive):
            newState.loadState = .loading
            newState.papers = []
            effects.append(.fetch(page: 0, forceRefresh: false))

        // L9/L10: .loaded → tabBecameActive → depends on staleness
        case (.loaded, .tabBecameActive):
            effects.append(.restoreScrollPosition)
            if state.isStale(now: now) {
                newState.loadState = .refreshing
                effects.append(.fetch(page: 0, forceRefresh: true))
            }

        // L2: .loading → fetchSucceeded → .loaded
        case (.loading, .fetchSucceeded(let papers, let hasMore)):
            newState.loadState = .loaded
            newState.papers = papers
            newState.page = 0
            newState.hasMore = hasMore
            newState.lastFetchedAt = now
            if !papers.isEmpty {
                effects.append(.queueSummaries)
            }

        // L3: .loading → fetchFailed → .error
        case (.loading, .fetchFailed(let error)):
            newState.loadState = .error(error)

        // L4: .error → retryTapped → .loading
        case (.error, .retryTapped):
            newState.loadState = .loading
            newState.papers = []
            effects.append(.fetch(page: 0, forceRefresh: false))

        // L: .error → pullToRefresh → .loading
        case (.error, .pullToRefresh):
            newState.loadState = .loading
            newState.papers = []
            effects.append(.fetch(page: 0, forceRefresh: true))

        // L5: .loaded, hasMore → loadMoreTriggered → .loadingMore
        case (.loaded, .loadMoreTriggered):
            if state.hasMore {
                newState.loadState = .loadingMore
                effects.append(.fetch(page: state.page + 1, forceRefresh: false))
            }
            // L6: hasMore=false → no-op

        // L7: .loadingMore → fetchSucceeded → .loaded, append + dedup
        case (.loadingMore, .fetchSucceeded(let papers, let hasMore)):
            let existingIds = Set(state.papers.map(\.id))
            let uniqueNew = papers.filter { !existingIds.contains($0.id) }
            newState.papers = state.papers + uniqueNew
            newState.loadState = .loaded
            newState.page = state.page + 1
            newState.hasMore = hasMore
            newState.lastFetchedAt = now
            effects.append(.queueSummaries)

        // L8: .loadingMore → fetchFailed → .loaded + toast
        case (.loadingMore, .fetchFailed):
            newState.loadState = .loaded
            effects.append(.showToast("Couldn't load more papers"))

        // L13: .loaded → pullToRefresh → .refreshing
        case (.loaded, .pullToRefresh):
            newState.loadState = .refreshing
            effects.append(.fetch(page: 0, forceRefresh: true))

        // L11: .refreshing → fetchSucceeded → .loaded, prepend new papers
        case (.refreshing, .fetchSucceeded(let papers, let hasMore)):
            let existingIds = Set(state.papers.map(\.id))
            let newPapers = papers.filter { !existingIds.contains($0.id) }
            if newPapers.isEmpty {
                newState.lastFetchedAt = now
                newState.loadState = .loaded
            } else {
                newState.papers = newPapers + state.papers
                newState.newPaperCount = newPapers.count
                newState.lastFetchedAt = now
                newState.hasMore = hasMore
                newState.loadState = .loaded
                newState.page = 0
                if let scrollPos = state.scrollPosition, !scrollPos.isEmpty {
                    newState.showNewPapersPill = true
                }
                effects.append(.queueSummaries)
            }

        // L12: .refreshing → fetchFailed → .loaded + toast
        case (.refreshing, .fetchFailed):
            newState.loadState = .loaded
            effects.append(.showToast("Couldn't refresh — showing cached papers"))

        // L16: .loading → tabBecameInactive → .empty
        case (.loading, .tabBecameInactive(let scrollPos)):
            newState.loadState = .empty
            newState.papers = []
            newState.scrollPosition = scrollPos
            effects.append(.cancelFetch)
            if let scrollPos {
                effects.append(.saveScrollPosition(scrollPos))
            }

        // L15: .loadingMore → tabBecameInactive → .loaded
        case (.loadingMore, .tabBecameInactive(let scrollPos)):
            newState.loadState = .loaded
            newState.scrollPosition = scrollPos
            effects.append(.cancelFetch)
            effects.append(.saveScrollPosition(scrollPos))

        // L17: .refreshing → tabBecameInactive → .loaded
        case (.refreshing, .tabBecameInactive(let scrollPos)):
            newState.loadState = .loaded
            newState.scrollPosition = scrollPos
            effects.append(.cancelFetch)
            effects.append(.saveScrollPosition(scrollPos))

        // .loaded → tabBecameInactive → save scroll
        case (.loaded, .tabBecameInactive(let scrollPos)):
            newState.scrollPosition = scrollPos
            effects.append(.saveScrollPosition(scrollPos))

        // .error → tabBecameInactive → no-op (stay in error)
        case (.error, .tabBecameInactive(let scrollPos)):
            newState.scrollPosition = scrollPos

        // Categories changed from ANY state → .loading + clear + fetch
        case (_, .categoriesChanged):
            effects.append(.cancelFetch)
            effects.append(.cancelSummaries)
            newState.loadState = .loading
            newState.papers = []
            newState.page = 0
            newState.scrollPosition = nil
            newState.showNewPapersPill = false
            effects.append(.fetch(page: 0, forceRefresh: true))

        // App foregrounded
        case (.loaded, .appForegrounded):
            if state.isStale(now: now) {
                newState.loadState = .refreshing
                effects.append(.fetch(page: 0, forceRefresh: true))
            }

        // New papers pill
        case (_, .newPapersPillTapped):
            newState.showNewPapersPill = false
            newState.resumeScrollPosition = state.scrollPosition
            newState.newPaperCount = 0
            effects.append(.scrollToTop)

        case (_, .newPapersPillDismissed):
            newState.showNewPapersPill = false

        case (_, .resumeReadingTapped):
            newState.scrollPosition = state.resumeScrollPosition
            newState.resumeScrollPosition = nil

        // Scroll position changed → persist
        case (_, .scrollPositionChanged(let pos)):
            newState.scrollPosition = pos
            if let pos {
                effects.append(.saveScrollPosition(pos))
            }

        // All other combinations: no-op
        default:
            break
        }

        return (newState, effects)
    }

    // MARK: - Trending Tab

    private static func transitionTrending(
        state: TabState,
        event: FeedEvent,
        now: Date
    ) -> (TabState, [FeedSideEffect]) {
        var newState = state
        var effects: [FeedSideEffect] = []

        switch (state.loadState, event) {

        // T1: .empty → tabBecameActive → .loading + restore scroll
        case (.empty, .tabBecameActive):
            newState.loadState = .loading
            effects.append(.restoreScrollPosition)
            effects.append(.fetchTrending)

        // T: .error → tabBecameActive → .loading (auto-retry)
        case (.error, .tabBecameActive):
            newState.loadState = .loading
            newState.papers = []
            effects.append(.fetchTrending)

        // T6/T7: .loaded → tabBecameActive → depends on staleness
        case (.loaded, .tabBecameActive):
            effects.append(.restoreScrollPosition)
            if state.isStale(now: now) {
                newState.loadState = .refreshing
                effects.append(.fetchTrending)
            }

        // T2: .loading → fetchSucceeded → .loaded (hasMore always false)
        case (.loading, .fetchSucceeded(let papers, _)):
            newState.loadState = .loaded
            newState.papers = papers
            newState.hasMore = false // trending never paginates
            newState.lastFetchedAt = now
            if !papers.isEmpty {
                effects.append(.queueSummaries)
            }

        // T3: .loading → fetchFailed → .error
        case (.loading, .fetchFailed(let error)):
            newState.loadState = .error(error)

        // T4: .error → retryTapped → .loading
        case (.error, .retryTapped):
            newState.loadState = .loading
            newState.papers = []
            effects.append(.fetchTrending)

        // T5: .loaded → loadMoreTriggered → no-op (trending doesn't paginate)
        case (.loaded, .loadMoreTriggered):
            break

        // T10: .loaded → pullToRefresh → .refreshing
        case (.loaded, .pullToRefresh):
            newState.loadState = .refreshing
            effects.append(.fetchTrending)

        // T8: .refreshing → fetchSucceeded → .loaded, prepend new papers
        case (.refreshing, .fetchSucceeded(let papers, _)):
            let existingIds = Set(state.papers.map(\.id))
            let newPapers = papers.filter { !existingIds.contains($0.id) }
            if newPapers.isEmpty {
                newState.lastFetchedAt = now
                newState.loadState = .loaded
            } else {
                newState.papers = newPapers + state.papers
                newState.newPaperCount = newPapers.count
                newState.lastFetchedAt = now
                newState.hasMore = false
                newState.loadState = .loaded
                if let scrollPos = state.scrollPosition, !scrollPos.isEmpty {
                    newState.showNewPapersPill = true
                }
                effects.append(.queueSummaries)
            }

        // T9: .refreshing → fetchFailed → .loaded + toast
        case (.refreshing, .fetchFailed):
            newState.loadState = .loaded
            effects.append(.showToast("Couldn't refresh — showing cached papers"))

        // Tab becomes inactive
        case (.loading, .tabBecameInactive(let scrollPos)):
            newState.loadState = .empty
            newState.papers = []
            newState.scrollPosition = scrollPos
            effects.append(.cancelFetch)

        case (.refreshing, .tabBecameInactive(let scrollPos)):
            newState.loadState = .loaded
            newState.scrollPosition = scrollPos
            effects.append(.cancelFetch)
            effects.append(.saveScrollPosition(scrollPos))

        case (.loaded, .tabBecameInactive(let scrollPos)):
            newState.scrollPosition = scrollPos
            effects.append(.saveScrollPosition(scrollPos))

        case (.error, .tabBecameInactive(let scrollPos)):
            newState.scrollPosition = scrollPos

        // Categories changed from ANY state
        case (_, .categoriesChanged):
            effects.append(.cancelFetch)
            effects.append(.cancelSummaries)
            newState.loadState = .loading
            newState.papers = []
            newState.page = 0
            newState.scrollPosition = nil
            newState.showNewPapersPill = false
            effects.append(.fetchTrending)

        // App foregrounded
        case (.loaded, .appForegrounded):
            if state.isStale(now: now) {
                newState.loadState = .refreshing
                effects.append(.fetchTrending)
            }

        // New papers pill
        case (_, .newPapersPillTapped):
            newState.showNewPapersPill = false
            newState.resumeScrollPosition = state.scrollPosition
            newState.newPaperCount = 0
            effects.append(.scrollToTop)

        case (_, .newPapersPillDismissed):
            newState.showNewPapersPill = false

        case (_, .resumeReadingTapped):
            newState.scrollPosition = state.resumeScrollPosition
            newState.resumeScrollPosition = nil

        // Scroll position changed → persist
        case (_, .scrollPositionChanged(let pos)):
            newState.scrollPosition = pos
            if let pos {
                effects.append(.saveScrollPosition(pos))
            }

        default:
            break
        }

        return (newState, effects)
    }

    // MARK: - Topics Tab

    /// Topics tab is managed by TopicListViewModel, not the feed state machine.
    /// Only scroll position save/restore is handled here.
    private static func transitionTopics(
        state: TabState,
        event: FeedEvent,
        now: Date
    ) -> (TabState, [FeedSideEffect]) {
        var newState = state
        var effects: [FeedSideEffect] = []

        switch event {
        case .tabBecameActive:
            newState.loadState = .loaded
            if state.loadState == .loaded {
                effects.append(.restoreScrollPosition)
            }

        case .tabBecameInactive(let scrollPos):
            newState.scrollPosition = scrollPos
            if let scrollPos {
                effects.append(.saveScrollPosition(scrollPos))
            }

        default:
            break
        }

        return (newState, effects)
    }

    // MARK: - Saved Tab

    private static func transitionSaved(
        state: TabState,
        event: FeedEvent,
        now: Date
    ) -> (TabState, [FeedSideEffect]) {
        var newState = state
        var effects: [FeedSideEffect] = []

        switch event {

        // S1/S2: tabBecameActive → query SwiftData
        case .tabBecameActive:
            newState.loadState = .loaded
            effects.append(.querySwiftData)
            if state.loadState == .loaded {
                effects.append(.restoreScrollPosition)
            }

        // Tab becomes inactive → save scroll
        case .tabBecameInactive(let scrollPos):
            newState.scrollPosition = scrollPos
            if let scrollPos {
                effects.append(.saveScrollPosition(scrollPos))
            }

        // S3/S4: bookmark changes → re-query
        case .paperBookmarked:
            effects.append(.querySwiftData)

        case .paperUnbookmarked:
            effects.append(.querySwiftData)

        // Pull to refresh → just re-query SwiftData (no network)
        case .pullToRefresh:
            effects.append(.querySwiftData)

        // App foregrounded → re-query if active
        case .appForegrounded:
            effects.append(.querySwiftData)

        // S5: fetchSucceeded from querySwiftData → update papers
        case .fetchSucceeded(let papers, _):
            newState.papers = papers
            newState.loadState = .loaded
            if !papers.isEmpty {
                effects.append(.queueSummaries)
            }

        // Everything else: no-op for saved tab
        // categoriesChanged, loadMoreTriggered, retryTapped, etc.
        default:
            break
        }

        return (newState, effects)
    }
}

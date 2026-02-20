//
//  TabState.swift
//  Papercut
//

import Foundation

// MARK: - LoadState

enum LoadState: Equatable {
    case empty
    case loading
    case loaded
    case loadingMore
    case refreshing
    case error(String)
}

// MARK: - TabState

struct TabState {
    var papers: [Paper]
    var page: Int
    var scrollPosition: String?
    var loadState: LoadState
    var hasMore: Bool
    var lastFetchedAt: Date?
    var showNewPapersPill: Bool
    var newPaperCount: Int = 0
    var resumeScrollPosition: String?

    static let initial = TabState(
        papers: [],
        page: 0,
        scrollPosition: nil,
        loadState: .empty,
        hasMore: true,
        lastFetchedAt: nil,
        showNewPapersPill: false,
        newPaperCount: 0,
        resumeScrollPosition: nil
    )

    static let staleThreshold: TimeInterval = 3600 // 1 hour

    func isFresh(now: Date = Date()) -> Bool {
        guard let lastFetchedAt else { return false }
        return now.timeIntervalSince(lastFetchedAt) < Self.staleThreshold
    }

    func isStale(now: Date = Date()) -> Bool {
        guard lastFetchedAt != nil else { return true }
        return !isFresh(now: now)
    }
}

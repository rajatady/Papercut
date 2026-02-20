//
//  FeedSideEffect.swift
//  Papercut
//

import Foundation

enum FeedSideEffect: Equatable {
    case fetch(page: Int, forceRefresh: Bool)
    case fetchTrending
    case cancelFetch
    case querySwiftData
    case saveScrollPosition(String?)
    case restoreScrollPosition
    case showToast(String)
    case queueSummaries
    case cancelSummaries
    case scrollToTop
    case none
}

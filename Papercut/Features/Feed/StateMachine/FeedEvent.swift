//
//  FeedEvent.swift
//  Papercut
//

import Foundation

enum FeedEvent {
    case tabBecameActive
    case tabBecameInactive(saveScrollPosition: String?)
    case fetchSucceeded(papers: [Paper], hasMore: Bool)
    case fetchFailed(error: String)
    case loadMoreTriggered
    case pullToRefresh
    case retryTapped
    case categoriesChanged
    case appForegrounded
    case paperBookmarked(paperId: String)
    case paperUnbookmarked(paperId: String)
    case newPapersPillTapped
    case newPapersPillDismissed
    case resumeReadingTapped
    case scrollPositionChanged(String?)
}

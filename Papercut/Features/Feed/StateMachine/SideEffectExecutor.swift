//
//  SideEffectExecutor.swift
//  Papercut
//

import Foundation

/// Executes side effects produced by the state machine.
/// Real implementation hits PaperRepository/network.
/// Test implementation records effects and returns stubs.
protocol SideEffectExecutor: Sendable {
    @MainActor func execute(
        _ effect: FeedSideEffect,
        for tab: FeedTab,
        categories: [String]
    ) async -> FeedEvent?
}

/// Real implementation that bridges state machine side effects to PaperRepository calls.
@MainActor
final class RealSideEffectExecutor: SideEffectExecutor {
    private let paperRepository: PaperRepository
    private var activeTask: Task<Void, Never>?

    init(paperRepository: PaperRepository) {
        self.paperRepository = paperRepository
    }

    func execute(
        _ effect: FeedSideEffect,
        for tab: FeedTab,
        categories: [String]
    ) async -> FeedEvent? {
        switch effect {

        case .fetch(let page, let forceRefresh):
            do {
                if forceRefresh {
                    paperRepository.resetPagination()
                }
                let mode: FeedMode = tab == .trending ? .trending : .latest
                let papers = try await paperRepository.fetchPapers(
                    categories: categories,
                    page: page,
                    forceRefresh: forceRefresh,
                    mode: mode
                )
                return .fetchSucceeded(papers: papers, hasMore: paperRepository.canLoadMore)
            } catch {
                return .fetchFailed(error: error.localizedDescription)
            }

        case .fetchTrending:
            do {
                let papers = try await paperRepository.fetchPapers(
                    categories: categories,
                    page: 0,
                    forceRefresh: true,
                    mode: .trending
                )
                return .fetchSucceeded(papers: papers, hasMore: false)
            } catch {
                return .fetchFailed(error: error.localizedDescription)
            }

        case .cancelFetch:
            activeTask?.cancel()
            activeTask = nil
            return nil

        case .querySwiftData:
            let savedPapers = paperRepository.fetchBookmarkedPapers()
                .sorted { ($0.bookmarkedAt ?? .distantPast) > ($1.bookmarkedAt ?? .distantPast) }
            return .fetchSucceeded(papers: savedPapers, hasMore: false)

        case .saveScrollPosition, .restoreScrollPosition, .scrollToTop:
            // Handled by the ViewModel/View layer directly
            return nil

        case .showToast:
            // Handled by the ViewModel directly
            return nil

        case .queueSummaries, .cancelSummaries:
            // Handled by the ViewModel's summarization logic
            return nil

        case .none:
            return nil
        }
    }

    func cancelActive() {
        activeTask?.cancel()
        activeTask = nil
    }
}

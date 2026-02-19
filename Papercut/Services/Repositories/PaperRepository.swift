//
//  PaperRepository.swift
//  Papercut
//

import Foundation
import SwiftData

enum FeedMode {
    case latest
    case trending
    case search(query: String)
}

protocol PaperRepositoryProtocol {
    func fetchPapers(categories: [String], page: Int, forceRefresh: Bool, mode: FeedMode) async throws -> [Paper]
    func searchPapers(query: String, page: Int) async throws -> [Paper]
    func getPaper(id: String) async -> Paper?
    func summarize(paper: Paper, style: SummaryStyle) async throws -> Summary
    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error>
    func cleanupOldPapers(retentionDays: Int) async
}

@MainActor
final class PaperRepository: PaperRepositoryProtocol {
    private let arXivService: ArXivServiceProtocol
    private let summarizationService: any SummarizationServiceProtocol
    private let modelContext: ModelContext

    private var currentPage = 0
    private var hasMorePapers = true
    private var isFetching = false

    init(
        arXivService: ArXivServiceProtocol,
        summarizationService: any SummarizationServiceProtocol,
        modelContext: ModelContext
    ) {
        self.arXivService = arXivService
        self.summarizationService = summarizationService
        self.modelContext = modelContext
    }

    // MARK: - Paper Fetching

    func fetchPapers(
        categories: [String],
        page: Int = 0,
        forceRefresh: Bool = false,
        mode: FeedMode = .latest
    ) async throws -> [Paper] {
        // Allow new fetches to proceed - don't block on isFetching
        // This prevents "No papers found" when switching tabs quickly
        isFetching = true
        defer { isFetching = false }

        // If page 0 and not forcing refresh, try cache first
        if page == 0 && !forceRefresh {
            let cachedPapers = try fetchCachedPapers(for: categories)
            if let firstPaper = cachedPapers.first, !firstPaper.isStale {
                return cachedPapers
            }
        }

        // Fetch from API based on mode
        let response: ArXivResponse
        switch mode {
        case .latest:
            response = try await arXivService.fetchPapers(
                categories: categories,
                page: page,
                pageSize: ArXivEndpoint.defaultPageSize,
                sortBy: .submittedDate
            )
        case .trending:
            response = try await arXivService.fetchTrending(
                categories: categories,
                limit: 50
            )
        case .search(let query):
            response = try await arXivService.searchPapers(
                query: query,
                page: page,
                pageSize: ArXivEndpoint.defaultPageSize
            )
        }

        hasMorePapers = response.hasMore
        currentPage = page

        // Merge into SwiftData and return the persisted objects
        // (so bookmark state etc. is preserved)
        var result: [Paper] = []
        for paper in response.papers {
            let paperId = paper.id
            let existingPapers = try fetchPaperById(paperId)

            if let existing = existingPapers.first {
                existing.title = paper.title
                existing.abstract = paper.abstract
                existing.authorsData = paper.authorsData
                existing.categoriesData = paper.categoriesData
                existing.updatedDate = paper.updatedDate
                existing.markAsRefreshed()
                result.append(existing)
            } else {
                modelContext.insert(paper)
                result.append(paper)
            }
        }

        try modelContext.save()

        return result
    }

    func searchPapers(query: String, page: Int = 0) async throws -> [Paper] {
        guard !isFetching else { return [] }
        isFetching = true
        defer { isFetching = false }

        let response = try await arXivService.searchPapers(
            query: query,
            page: page,
            pageSize: ArXivEndpoint.defaultPageSize
        )

        hasMorePapers = response.hasMore
        currentPage = page

        // Cache search results too
        for paper in response.papers {
            let paperId = paper.id
            let existingPapers = try fetchPaperById(paperId)

            if existingPapers.isEmpty {
                modelContext.insert(paper)
            }
        }

        try modelContext.save()

        return response.papers
    }

    private func fetchPaperById(_ paperId: String) throws -> [Paper] {
        var descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate<Paper> { $0.id == paperId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    func getPaper(id: String) async -> Paper? {
        return try? fetchPaperById(id).first
    }

    private func fetchCachedPapers(for categories: [String]) throws -> [Paper] {
        let descriptor = FetchDescriptor<Paper>(
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )

        let allPapers = try modelContext.fetch(descriptor)

        let categorySet = Set(categories)
        return allPapers.filter { paper in
            !Set(paper.categories).isDisjoint(with: categorySet)
        }
    }

    // MARK: - Summarization

    func summarize(paper: Paper, style: SummaryStyle) async throws -> Summary {
        if let existingSummary = paper.summary(for: style), existingSummary.isComplete {
            return existingSummary
        }

        let content = try await summarizationService.summarize(paper: paper, style: style)

        let summary = Summary(paperId: paper.id, style: style, content: content, isComplete: true)
        paper.addSummary(summary)
        modelContext.insert(summary)
        try modelContext.save()

        return summary
    }

    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error> {
        if let existingSummary = paper.summary(for: style), existingSummary.isComplete {
            return AsyncThrowingStream { continuation in
                continuation.yield(existingSummary.content)
                continuation.finish()
            }
        }

        let summary: Summary
        if let existing = paper.summary(for: style) {
            summary = existing
        } else {
            summary = Summary(paperId: paper.id, style: style)
            paper.addSummary(summary)
            modelContext.insert(summary)
        }

        let stream = summarizationService.summarizeStreaming(paper: paper, style: style)

        return AsyncThrowingStream { [weak self] continuation in
            Task { @MainActor in
                var fullContent = ""

                do {
                    for try await chunk in stream {
                        fullContent += chunk
                        summary.content = fullContent
                        continuation.yield(fullContent)
                    }

                    summary.isComplete = true
                    try self?.modelContext.save()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Auto Summarization

    func autoSummarize(paper: Paper) async {
        let style = SummaryStyle.autoSummaryStyle
        guard !paper.hasSummary(for: style) else { return }

        do {
            _ = try await summarize(paper: paper, style: style)
        } catch {
            print("Auto-summarization failed: \(error)")
        }
    }

    // MARK: - Cleanup

    // MARK: - Bookmarks

    func fetchBookmarkedPapers() -> [Paper] {
        var descriptor = FetchDescriptor<Paper>(
            predicate: #Predicate<Paper> { $0.isBookmarked == true }
        )
        descriptor.sortBy = [SortDescriptor(\.bookmarkedAt, order: .reverse)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func toggleBookmark(for paper: Paper) {
        paper.isBookmarked.toggle()
        paper.bookmarkedAt = paper.isBookmarked ? Date() : nil
        try? modelContext.save()
    }

    // MARK: - Cleanup

    func cleanupOldPapers(retentionDays: Int) async {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) ?? Date()

        let descriptor = FetchDescriptor<Paper>()

        do {
            let allPapers = try modelContext.fetch(descriptor)
            // Never delete bookmarked papers
            let oldPapers = allPapers.filter { $0.fetchedAt < cutoffDate && !$0.isBookmarked }
            for paper in oldPapers {
                modelContext.delete(paper)
            }
            try modelContext.save()
        } catch {
            print("Failed to cleanup old papers: \(error)")
        }
    }

    // MARK: - State

    var canLoadMore: Bool {
        hasMorePapers && !isFetching
    }

    func resetPagination() {
        currentPage = 0
        hasMorePapers = true
    }
}

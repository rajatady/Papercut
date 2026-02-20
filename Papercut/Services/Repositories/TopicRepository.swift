//
//  TopicRepository.swift
//  Papercut
//

import Foundation
import SwiftData

@MainActor
final class TopicRepository {
    private let modelContext: ModelContext
    private let arXivService: ArXivServiceProtocol

    init(modelContext: ModelContext, arXivService: ArXivServiceProtocol) {
        self.modelContext = modelContext
        self.arXivService = arXivService
    }

    // MARK: - CRUD

    @discardableResult
    func createTopic(name: String, query: String, sortBy: ArXivSortBy = .relevance) -> Topic {
        let topic = Topic(name: name, query: query, sortBy: sortBy)
        modelContext.insert(topic)
        try? modelContext.save()
        return topic
    }

    func deleteTopic(_ topic: Topic) {
        modelContext.delete(topic)
        try? modelContext.save()
    }

    func fetchAllTopics() -> [Topic] {
        let descriptor = FetchDescriptor<Topic>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func updateTopic(_ topic: Topic, name: String, query: String, sortBy: ArXivSortBy) {
        let queryChanged = topic.query != query
        topic.name = name
        topic.query = query
        topic.setSortBy(sortBy)
        if queryChanged {
            topic.paperIds = []
            topic.totalResults = 0
            topic.scrollPosition = nil
            topic.isPopulating = false
        }
        try? modelContext.save()
    }

    // MARK: - Topic Population (Full Fetch)

    /// Fetches ALL papers for a topic from arXiv in batches of 200.
    /// Papers are stored in SwiftData and IDs appended to topic.paperIds.
    /// Sorted by submittedDate ascending for chronological timeline.
    func populateTopic(
        _ topic: Topic,
        progress: @escaping (Int, Int) -> Void
    ) async throws {
        topic.isPopulating = true
        try? modelContext.save()

        defer {
            topic.isPopulating = false
            try? modelContext.save()
        }

        // First: get total results count with a minimal fetch
        let probe = try await arXivService.searchPapers(
            query: topic.query,
            page: 0,
            pageSize: 1,
            sortBy: topic.sortBy,
            sortOrder: .descending,
            categories: []
        )
        topic.totalResults = probe.totalResults
        try? modelContext.save()

        let pageSize = ArXivEndpoint.topicPageSize
        let totalPages = (probe.totalResults + pageSize - 1) / pageSize
        var fetchedCount = topic.paperIds.count

        // Resume from where we left off if partially populated
        let startPage = fetchedCount / pageSize

        for page in startPage..<totalPages {
            try Task.checkCancellation()

            let response = try await arXivService.searchPapers(
                query: topic.query,
                page: page,
                pageSize: pageSize,
                sortBy: topic.sortBy,
                sortOrder: .descending,
                categories: []
            )

            // Merge papers into SwiftData (upsert pattern)
            var batchIds: [String] = []
            for paper in response.papers {
                let paperId = paper.id
                batchIds.append(paperId)

                var descriptor = FetchDescriptor<Paper>(
                    predicate: #Predicate<Paper> { $0.id == paperId }
                )
                descriptor.fetchLimit = 1
                let existing = try? modelContext.fetch(descriptor)

                if let existingPaper = existing?.first {
                    existingPaper.title = paper.title
                    existingPaper.abstract = paper.abstract
                    existingPaper.authorsData = paper.authorsData
                    existingPaper.categoriesData = paper.categoriesData
                    existingPaper.updatedDate = paper.updatedDate
                    existingPaper.markAsRefreshed()
                } else {
                    modelContext.insert(paper)
                }
            }

            topic.appendPaperIds(batchIds)
            fetchedCount = topic.paperIds.count
            try? modelContext.save()

            progress(fetchedCount, probe.totalResults)
        }

        topic.lastCheckedAt = Date()
        topic.lastPaperCount = topic.paperIds.count
        try? modelContext.save()
    }

    // MARK: - Cached Paper Loading (Offline-First)

    /// Loads papers from SwiftData by IDs stored in topic.paperIds.
    /// Returns papers in the order they appear in paperIds (chronological).
    func loadCachedPapers(for topic: Topic, range: Range<Int>? = nil) -> [Paper] {
        let ids = topic.paperIds
        guard !ids.isEmpty else { return [] }

        let slicedIds: ArraySlice<String>
        if let range {
            let clampedRange = range.clamped(to: 0..<ids.count)
            slicedIds = ids[clampedRange]
        } else {
            slicedIds = ids[0..<ids.count]
        }

        let idSet = Set(slicedIds)
        let descriptor = FetchDescriptor<Paper>()
        guard let allMatching = try? modelContext.fetch(descriptor) else { return [] }

        let paperMap = Dictionary(uniqueKeysWithValues:
            allMatching.filter { idSet.contains($0.id) }.map { ($0.id, $0) }
        )

        // Preserve order from paperIds
        return slicedIds.compactMap { paperMap[$0] }
    }

    // MARK: - Check for New Papers

    /// Fetches recent papers and checks if any are new (not already in topic.paperIds).
    /// Returns count of new papers found and prepends them to topic.paperIds.
    func checkForNewPapers(_ topic: Topic) async throws -> Int {
        let response = try await arXivService.searchPapers(
            query: topic.query,
            page: 0,
            pageSize: ArXivEndpoint.topicPageSize,
            sortBy: topic.sortBy,
            sortOrder: .descending,
            categories: []
        )

        let existingSet = Set(topic.paperIds)
        var newPaperIds: [String] = []

        for paper in response.papers {
            let paperId = paper.id
            if !existingSet.contains(paperId) {
                newPaperIds.append(paperId)

                // Upsert into SwiftData
                var descriptor = FetchDescriptor<Paper>(
                    predicate: #Predicate<Paper> { $0.id == paperId }
                )
                descriptor.fetchLimit = 1
                let existing = try? modelContext.fetch(descriptor)

                if existing?.first == nil {
                    modelContext.insert(paper)
                }
            }
        }

        if !newPaperIds.isEmpty {
            // New papers go at the END (they're newer, timeline is chronological ascending)
            topic.appendPaperIds(newPaperIds)
            topic.lastCheckedAt = Date()
            topic.lastPaperCount = topic.paperIds.count
            topic.totalResults = topic.paperIds.count
            try? modelContext.save()
        }

        return newPaperIds.count
    }

    // MARK: - Legacy (for backward compatibility during transition)

    func fetchPapersForTopic(_ topic: Topic, page: Int = 0) async throws -> [Paper] {
        let response = try await arXivService.searchPapers(
            query: topic.query,
            page: page,
            pageSize: ArXivEndpoint.defaultPageSize,
            sortBy: topic.sortBy,
            sortOrder: .descending,
            categories: []
        )
        return response.papers
    }

    // MARK: - State Updates

    func updateLastChecked(_ topic: Topic, paperCount: Int) {
        topic.lastCheckedAt = Date()
        topic.lastPaperCount = paperCount
        try? modelContext.save()
    }
}

//
//  TopicRepositoryTests.swift
//  PapercutTests
//

import Testing
import Foundation
import SwiftData
@testable import Papercut

@Suite(.serialized)
struct TopicRepositoryTests {

    // MARK: - CRUD

    @MainActor
    @Test func createTopic_persistsTopic() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "LLMs", query: "large language model")

        let all = repo.fetchAllTopics()
        #expect(all.count == 1)
        #expect(all.first?.name == "LLMs")
        #expect(all.first?.query == "large language model")
        #expect(all.first?.id == topic.id)
    }

    @MainActor
    @Test func deleteTopic_removesFromStore() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "Test", query: "test")
        #expect(repo.fetchAllTopics().count == 1)

        repo.deleteTopic(topic)
        #expect(repo.fetchAllTopics().isEmpty)
    }

    @MainActor
    @Test func fetchAllTopics_returnsAll() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        repo.createTopic(name: "A", query: "a")
        repo.createTopic(name: "B", query: "b")
        repo.createTopic(name: "C", query: "c")

        #expect(repo.fetchAllTopics().count == 3)
    }

    @MainActor
    @Test func fetchAllTopics_emptyByDefault() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        #expect(repo.fetchAllTopics().isEmpty)
    }

    @MainActor
    @Test func fetchAllTopics_orderedByCreatedAtDescending() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        repo.createTopic(name: "First", query: "first")
        repo.createTopic(name: "Second", query: "second")

        let all = repo.fetchAllTopics()
        #expect(all.first?.createdAt ?? .distantPast >= all.last?.createdAt ?? .distantFuture)
    }

    // MARK: - Paper Fetching

    @MainActor
    @Test func fetchPapersForTopic_callsArXivSearch() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        mockArXiv.papers = [
            Paper(id: "1", title: "Neural Network Paper", abstract: "Abs", authors: [], categories: ["cs.AI"],
                  publishedDate: Date(), updatedDate: Date(), pdfURL: "", abstractURL: "")
        ]
        mockArXiv.totalResults = 1

        let topic = repo.createTopic(name: "Test", query: "neural")
        let papers = try await repo.fetchPapersForTopic(topic)

        #expect(papers.count == 1)
        #expect(mockArXiv.searchCallCount == 1)
    }

    @MainActor
    @Test func fetchPapersForTopic_usesSortPreference() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        mockArXiv.papers = []
        mockArXiv.totalResults = 0

        let topic = repo.createTopic(name: "Test", query: "neural", sortBy: .submittedDate)
        _ = try await repo.fetchPapersForTopic(topic)

        #expect(mockArXiv.searchCallCount == 1)
    }

    // MARK: - State Updates

    @MainActor
    @Test func updateLastChecked_setsDateAndCount() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "Test", query: "test")

        #expect(topic.lastCheckedAt == nil)
        #expect(topic.lastPaperCount == 0)

        let before = Date()
        repo.updateLastChecked(topic, paperCount: 42)

        #expect(topic.lastCheckedAt != nil)
        #expect(topic.lastCheckedAt! >= before)
        #expect(topic.lastPaperCount == 42)
    }

    // MARK: - Update Topic

    @MainActor
    @Test func updateTopic_changesNameAndQuery() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "Old", query: "old query")
        repo.updateTopic(topic, name: "New", query: "new query", sortBy: .submittedDate)

        #expect(topic.name == "New")
        #expect(topic.query == "new query")
        #expect(topic.sortBy == .submittedDate)
    }

    @MainActor
    @Test func updateTopic_queryChanged_clearsPaperIds() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "Test", query: "old query")
        topic.paperIds = ["id1", "id2"]
        topic.totalResults = 100
        topic.scrollPosition = "id1"

        repo.updateTopic(topic, name: "Test", query: "new query", sortBy: .relevance)

        #expect(topic.paperIds.isEmpty)
        #expect(topic.totalResults == 0)
        #expect(topic.scrollPosition == nil)
    }

    @MainActor
    @Test func updateTopic_sameQuery_keepsPaperIds() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "Test", query: "same query")
        topic.paperIds = ["id1", "id2"]

        repo.updateTopic(topic, name: "New Name", query: "same query", sortBy: .submittedDate)

        #expect(topic.paperIds == ["id1", "id2"])
    }

    // MARK: - Load Cached Papers

    @MainActor
    @Test func loadCachedPapers_emptyTopic_returnsEmpty() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Paper.self, Summary.self, Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        let topic = repo.createTopic(name: "Test", query: "test")
        let papers = repo.loadCachedPapers(for: topic)
        #expect(papers.isEmpty)
    }

    @MainActor
    @Test func loadCachedPapers_returnsPapersInOrder() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Paper.self, Summary.self, Topic.self, configurations: config)
        let context = container.mainContext
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: context, arXivService: mockArXiv)

        // Insert papers
        let p1 = Paper(id: "p1", title: "Paper 1", abstract: "A", authors: [], categories: ["cs.AI"],
                       publishedDate: Date(), updatedDate: Date(), pdfURL: "", abstractURL: "")
        let p2 = Paper(id: "p2", title: "Paper 2", abstract: "B", authors: [], categories: ["cs.AI"],
                       publishedDate: Date(), updatedDate: Date(), pdfURL: "", abstractURL: "")
        context.insert(p1)
        context.insert(p2)
        try? context.save()

        let topic = repo.createTopic(name: "Test", query: "test")
        topic.paperIds = ["p2", "p1"] // reversed order

        let papers = repo.loadCachedPapers(for: topic)
        #expect(papers.count == 2)
        #expect(papers[0].id == "p2")
        #expect(papers[1].id == "p1")
    }
}

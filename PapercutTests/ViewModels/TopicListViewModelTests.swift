//
//  TopicListViewModelTests.swift
//  PapercutTests
//

import Testing
import Foundation
import SwiftData
@testable import Papercut

@Suite(.serialized)
struct TopicListViewModelTests {

    // MARK: - Initial State

    @MainActor
    @Test func initialState_topicsEmpty() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        #expect(vm.topics.isEmpty)
        #expect(vm.selectedTopic == nil)
        #expect(vm.topicPapers.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingPapers == false)
        #expect(vm.error == nil)
    }

    // MARK: - Load Topics

    @MainActor
    @Test func loadTopics_fetchesFromRepository() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        repo.createTopic(name: "A", query: "a")
        repo.createTopic(name: "B", query: "b")

        vm.loadTopics()
        #expect(vm.topics.count == 2)
    }

    // MARK: - Create Topic

    @MainActor
    @Test func createTopic_addsTopic() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        vm.createTopic(name: "LLMs", query: "large language model")

        #expect(vm.topics.count == 1)
        #expect(vm.topics.first?.name == "LLMs")
    }

    @MainActor
    @Test func createTopic_emptyName_doesNothing() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        vm.createTopic(name: "", query: "test")
        #expect(vm.topics.isEmpty)
    }

    @MainActor
    @Test func createTopic_emptyQuery_doesNothing() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        vm.createTopic(name: "Test", query: "  ")
        #expect(vm.topics.isEmpty)
    }

    @MainActor
    @Test func createTopic_trimsWhitespace() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        vm.createTopic(name: "  LLMs  ", query: "  large language model  ")

        #expect(vm.topics.first?.name == "LLMs")
        #expect(vm.topics.first?.query == "large language model")
    }

    // MARK: - Delete Topic

    @MainActor
    @Test func deleteTopic_removesFromList() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: MockArXivService())
        let vm = TopicListViewModel(topicRepository: repo)

        vm.createTopic(name: "Test", query: "test")
        #expect(vm.topics.count == 1)

        let topic = vm.topics.first!
        vm.deleteTopic(topic)
        #expect(vm.topics.isEmpty)
    }

    @MainActor
    @Test func deleteTopic_clearsSelectionIfSelected() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: mockArXiv)
        let vm = TopicListViewModel(topicRepository: repo)

        mockArXiv.papers = []
        mockArXiv.totalResults = 0

        vm.createTopic(name: "Test", query: "test")
        let topic = vm.topics.first!
        await vm.selectTopic(topic)
        #expect(vm.selectedTopic != nil)

        vm.deleteTopic(topic)
        #expect(vm.selectedTopic == nil)
        #expect(vm.topicPapers.isEmpty)
    }

    // MARK: - Select / Deselect Topic

    @MainActor
    @Test func selectTopic_setsSelectedTopic() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: mockArXiv)
        let vm = TopicListViewModel(topicRepository: repo)

        mockArXiv.papers = []
        mockArXiv.totalResults = 0

        vm.createTopic(name: "Test", query: "test")
        let topic = vm.topics.first!

        await vm.selectTopic(topic)
        #expect(vm.selectedTopic?.id == topic.id)
    }

    @MainActor
    @Test func selectTopic_loadsPapers() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: mockArXiv)
        let vm = TopicListViewModel(topicRepository: repo)

        mockArXiv.papers = [
            Paper(id: "1", title: "Neural Network Paper", abstract: "Abs", authors: [], categories: ["cs.AI"],
                  publishedDate: Date(), updatedDate: Date(), pdfURL: "", abstractURL: "")
        ]
        mockArXiv.totalResults = 1

        vm.createTopic(name: "Test", query: "neural")
        let topic = vm.topics.first!

        await vm.selectTopic(topic)
        #expect(vm.topicPapers.count == 1)
        #expect(vm.isLoadingPapers == false)
    }

    @MainActor
    @Test func selectTopic_apiError_setsError() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: mockArXiv)
        let vm = TopicListViewModel(topicRepository: repo)

        mockArXiv.shouldFail = true

        vm.createTopic(name: "Test", query: "test")
        let topic = vm.topics.first!

        await vm.selectTopic(topic)
        #expect(vm.error != nil)
        #expect(vm.topicPapers.isEmpty)
        #expect(vm.isLoadingPapers == false)
    }

    @MainActor
    @Test func deselectTopic_clearsSelection() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Topic.self, configurations: config)
        let mockArXiv = MockArXivService()
        let repo = TopicRepository(modelContext: container.mainContext, arXivService: mockArXiv)
        let vm = TopicListViewModel(topicRepository: repo)

        mockArXiv.papers = []
        mockArXiv.totalResults = 0

        vm.createTopic(name: "Test", query: "test")
        await vm.selectTopic(vm.topics.first!)
        #expect(vm.selectedTopic != nil)

        vm.deselectTopic()
        #expect(vm.selectedTopic == nil)
        #expect(vm.topicPapers.isEmpty)
        #expect(vm.error == nil)
    }
}

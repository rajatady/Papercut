//
//  TopicListViewModel.swift
//  Papercut
//

import Foundation

@Observable
@MainActor
final class TopicListViewModel {
    private(set) var topics: [Topic] = []
    private(set) var selectedTopic: Topic?
    private(set) var topicPapers: [Paper] = []
    private(set) var isLoading = false
    private(set) var isLoadingPapers = false
    private(set) var error: String?

    private let topicRepository: TopicRepository

    init(topicRepository: TopicRepository) {
        self.topicRepository = topicRepository
        // Load immediately — fetchAllTopics is a synchronous SwiftData query
        self.topics = topicRepository.fetchAllTopics()
    }

    func loadTopics() {
        topics = topicRepository.fetchAllTopics()
    }

    func createTopic(name: String, query: String, sortBy: ArXivSortBy = .relevance) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedQuery.isEmpty else { return }

        topicRepository.createTopic(name: trimmedName, query: trimmedQuery, sortBy: sortBy)
        loadTopics()
    }

    func deleteTopic(_ topic: Topic) {
        topicRepository.deleteTopic(topic)
        if selectedTopic?.id == topic.id {
            deselectTopic()
        }
        loadTopics()
    }

    func selectTopic(_ topic: Topic) async {
        selectedTopic = topic
        isLoadingPapers = true
        error = nil

        do {
            let papers = try await topicRepository.fetchPapersForTopic(topic)
            topicPapers = papers
            topicRepository.updateLastChecked(topic, paperCount: papers.count)
        } catch {
            self.error = error.localizedDescription
            topicPapers = []
        }

        isLoadingPapers = false
    }

    func deselectTopic() {
        selectedTopic = nil
        topicPapers = []
        error = nil
    }
}

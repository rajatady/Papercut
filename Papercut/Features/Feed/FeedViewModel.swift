//
//  FeedViewModel.swift
//  Papercut
//

import Foundation
import SwiftUI
import SwiftData

enum ListBoundaryEdge {
    case top
    case bottom
}

enum FeedTab: String, CaseIterable {
    case latest = "Latest"
    case trending = "Trending"
    case saved = "Saved"
    case topics = "Topics"

    var iconName: String {
        switch self {
        case .latest: return "clock.fill"
        case .trending: return "flame.fill"
        case .saved: return "bookmark.fill"
        case .topics: return "text.magnifyingglass"
        }
    }
}

@Observable
@MainActor
final class FeedViewModel: SummarizationQueueDelegate {
    // MARK: - Per-Tab State (the state machine)
    var tabStates: [FeedTab: TabState] = [
        .latest: .initial,
        .trending: .initial,
        .saved: .initial,
        .topics: .initial,
    ]

    // Current feed state
    var currentTab: FeedTab = .latest
    var currentPaperIndex: Int = 0

    /// Transient error shown as a toast, auto-dismissed
    private(set) var toastError: String?

    /// "New papers available" pill visible
    var showNewPapersPill: Bool {
        tabStates[currentTab]?.showNewPapersPill ?? false
    }

    // List boundary haptic trigger
    var lastBoundaryReached: ListBoundaryEdge?

    // Search state
    var searchQuery = ""
    var isSearching = false
    private(set) var searchResults: [Paper] = []

    // Summarization state per paper (for UI updates)
    private(set) var summarizingPapers: Set<String> = []
    var streamingContent: [String: String] = [:]
    var selectedStyles: [String: SummaryStyle] = [:]
    var completedSummaries: [String: String] = [:] // requestId -> content

    /// Active async tasks per tab for cancellation
    private var activeTasks: [FeedTab: Task<Void, Never>] = [:]

    // MARK: - Topic Feed State
    private(set) var activeTopic: Topic?
    private(set) var topicPopulationProgress: (fetched: Int, total: Int)?
    private var topicPopulationTask: Task<Void, Never>?

    // MARK: - Dependencies
    let paperRepository: PaperRepository
    let topicRepository: TopicRepository
    private let preferencesStore: PreferencesStore
    private let cloudStore = CloudSummaryStore.shared
    private let summarizationQueue = SummarizationQueue.shared
    private let executor: SideEffectExecutor

    init(repository: PaperRepository, topicRepository: TopicRepository, preferencesStore: PreferencesStore) {
        self.paperRepository = repository
        self.topicRepository = topicRepository
        self.preferencesStore = preferencesStore
        self.executor = RealSideEffectExecutor(paperRepository: repository)

        // Configure the queue
        Task {
            await summarizationQueue.configure(
                service: SummarizationServiceFactory.create(),
                delegate: self
            )
        }
    }

    // For testing — inject a custom executor
    init(repository: PaperRepository, topicRepository: TopicRepository, preferencesStore: PreferencesStore, executor: SideEffectExecutor) {
        self.paperRepository = repository
        self.topicRepository = topicRepository
        self.preferencesStore = preferencesStore
        self.executor = executor

        Task {
            await summarizationQueue.configure(
                service: SummarizationServiceFactory.create(),
                delegate: self
            )
        }
    }

    // MARK: - Computed Properties (read from active tab's state)

    var papers: [Paper] {
        tabStates[currentTab]?.papers ?? []
    }

    var isLoading: Bool {
        tabStates[currentTab]?.loadState == .loading
    }

    var isLoadingMore: Bool {
        tabStates[currentTab]?.loadState == .loadingMore
    }

    var isRefreshingInBackground: Bool {
        tabStates[currentTab]?.loadState == .refreshing
    }

    var error: Error? {
        guard case .error(let msg) = tabStates[currentTab]?.loadState else { return nil }
        return NSError(domain: "FeedViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    var hasCategories: Bool {
        !preferencesStore.followedCategories.isEmpty
    }

    var enabledStyles: Set<SummaryStyle> {
        preferencesStore.enabledSummaryStyles
    }

    var canLoadMore: Bool {
        guard let state = tabStates[currentTab] else { return false }
        return currentTab != .saved && state.hasMore && state.loadState == .loaded
    }

    var currentPaper: Paper? {
        let p = papers
        guard currentPaperIndex >= 0 && currentPaperIndex < p.count else { return nil }
        return p[currentPaperIndex]
    }

    var displayPapers: [Paper] {
        isSearching && !searchQuery.isEmpty ? searchResults : papers
    }

    // MARK: - Event Dispatch (core of the state machine integration)

    /// Fire-and-forget: send an event, execute side effects asynchronously.
    func send(_ event: FeedEvent, for tab: FeedTab? = nil) {
        let targetTab = tab ?? currentTab
        guard tabStates[targetTab] != nil else { return }

        let (newState, effects) = TabStateMachine.transition(
            state: tabStates[targetTab]!,
            event: event,
            tab: targetTab
        )

        tabStates[targetTab] = newState

        for effect in effects {
            handleSideEffect(effect, for: targetTab)
        }
    }

    /// Send an event and wait for the async effect chain (fetch→result) to complete.
    /// Used by public API methods that callers `await`.
    func sendAndWait(_ event: FeedEvent, for tab: FeedTab? = nil) async {
        let targetTab = tab ?? currentTab
        guard tabStates[targetTab] != nil else { return }

        let (newState, effects) = TabStateMachine.transition(
            state: tabStates[targetTab]!,
            event: event,
            tab: targetTab
        )

        tabStates[targetTab] = newState

        // Execute effects — async ones (fetch, querySwiftData) are awaited inline
        for effect in effects {
            switch effect {
            case .fetch, .fetchTrending, .querySwiftData:
                // Execute inline and feed result back synchronously
                let categories = preferencesStore.followedCategories
                if let resultEvent = await executor.execute(effect, for: targetTab, categories: categories) {
                    send(resultEvent, for: targetTab)
                }

            default:
                handleSideEffect(effect, for: targetTab)
            }
        }
    }

    private func handleSideEffect(_ effect: FeedSideEffect, for tab: FeedTab) {
        switch effect {
        case .showToast(let message):
            showToast(message)

        case .cancelFetch:
            activeTasks[tab]?.cancel()
            activeTasks[tab] = nil

        case .cancelSummaries:
            Task {
                await summarizationQueue.clearAll()
            }

        case .queueSummaries:
            if let state = tabStates[tab], !state.papers.isEmpty {
                Task {
                    await queueSummariesForVisiblePaper(at: 0)
                }
            }

        case .saveScrollPosition(let pos):
            preferencesStore.saveScrollPosition(pos, for: tab)

        case .restoreScrollPosition:
            let saved = preferencesStore.savedScrollPosition(for: tab)
            if let saved {
                tabStates[tab]?.scrollPosition = saved
            }

        case .scrollToTop, .none:
            break

        case .fetch, .fetchTrending, .querySwiftData:
            activeTasks[tab]?.cancel()
            activeTasks[tab] = Task { [weak self] in
                guard let self else { return }
                let categories = self.preferencesStore.followedCategories
                if let resultEvent = await self.executor.execute(effect, for: tab, categories: categories) {
                    if !Task.isCancelled {
                        self.send(resultEvent, for: tab)
                    }
                }
            }
        }
    }

    // MARK: - Public API (preserved for FeedView compatibility)

    func loadPapers(forceRefresh: Bool = false) async {
        if currentTab != .saved && !hasCategories {
            tabStates[currentTab] = .initial
            return
        }
        if forceRefresh {
            await sendAndWait(.pullToRefresh)
        } else {
            await sendAndWait(.tabBecameActive)
        }
    }

    func loadMorePapers() async {
        await sendAndWait(.loadMoreTriggered)
    }

    func refresh() async {
        await sendAndWait(.pullToRefresh)
    }

    func switchTab(to tab: FeedTab, fromScrollPosition: String? = nil) async {
        guard currentTab != tab else { return }

        // Save scroll position and deactivate old tab
        send(.tabBecameInactive(saveScrollPosition: fromScrollPosition), for: currentTab)

        currentTab = tab

        // Activate new tab
        await sendAndWait(.tabBecameActive, for: tab)
    }

    func onCategoriesChanged() {
        for tab in FeedTab.allCases {
            send(.categoriesChanged, for: tab)
        }
    }

    func onAppForegrounded() {
        send(.appForegrounded)
    }

    func onPaperAppear(_ paper: Paper, at index: Int) {
        Task {
            await queueSummariesForVisiblePaper(at: index)
        }

        // Boundary haptic detection
        let p = displayPapers
        if p.count > 0 {
            if index == 0 {
                lastBoundaryReached = .top
            } else if index == p.count - 1 {
                lastBoundaryReached = .bottom
            } else {
                lastBoundaryReached = nil
            }
        }

        currentPaperIndex = index

        // Load more when near the end
        if p.count > 0 && index >= max(0, p.count - 3) {
            send(.loadMoreTriggered)
        }
    }

    func clearBoundary() {
        lastBoundaryReached = nil
    }

    func toggleBookmark(for paper: Paper) {
        paperRepository.toggleBookmark(for: paper)

        // Notify saved tab about bookmark change
        if paper.isBookmarked {
            send(.paperBookmarked(paperId: paper.id), for: .saved)
        } else {
            send(.paperUnbookmarked(paperId: paper.id), for: .saved)
        }
    }

    func dismissNewPapersPill() {
        send(.newPapersPillDismissed)
    }

    func scrollToNewPapers() {
        send(.newPapersPillTapped)
    }

    var hasResumePosition: Bool {
        tabStates[currentTab]?.resumeScrollPosition != nil
    }

    func resumeReading() -> String? {
        let pos = tabStates[currentTab]?.resumeScrollPosition
        send(.resumeReadingTapped)
        return pos
    }

    func onScrollPositionChanged(_ id: String?) {
        send(.scrollPositionChanged(id))
    }

    // MARK: - Topic Feed

    /// Opens a topic and loads its papers into the .topics tab state.
    func openTopic(_ topic: Topic) {
        activeTopic = topic
        currentPaperIndex = 0

        // Load cached papers (offline-first)
        let cachedPapers = topicRepository.loadCachedPapers(for: topic)

        if !cachedPapers.isEmpty {
            tabStates[.topics]?.papers = cachedPapers
            tabStates[.topics]?.loadState = .loaded
            tabStates[.topics]?.hasMore = false

            // Restore scroll position
            if let scrollPos = topic.scrollPosition {
                tabStates[.topics]?.scrollPosition = scrollPos
            }
        } else {
            // No cached papers — start population
            tabStates[.topics]?.loadState = .loading
            tabStates[.topics]?.papers = []
            populateActiveTopic()
        }
    }

    /// Closes the topic feed and returns to topic list.
    func closeTopic() {
        // Save scroll position to Topic model
        if let topic = activeTopic, let scrollPos = tabStates[.topics]?.scrollPosition {
            topic.scrollPosition = scrollPos
        }

        topicPopulationTask?.cancel()
        topicPopulationTask = nil
        activeTopic = nil
        topicPopulationProgress = nil
        currentPaperIndex = 0

        // Reset topics tab state to show topic list
        tabStates[.topics] = .initial
        tabStates[.topics]?.loadState = .loaded
    }

    /// Starts populating the active topic from arXiv.
    func populateActiveTopic() {
        guard let topic = activeTopic else { return }

        topicPopulationTask?.cancel()
        topicPopulationTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.topicRepository.populateTopic(topic) { fetched, total in
                    Task { @MainActor in
                        self.topicPopulationProgress = (fetched: fetched, total: total)

                        // Incrementally update papers in the tab
                        let papers = self.topicRepository.loadCachedPapers(for: topic)
                        self.tabStates[.topics]?.papers = papers
                        self.tabStates[.topics]?.loadState = .loaded
                    }
                }

                // Final update
                self.topicPopulationProgress = nil
                let papers = self.topicRepository.loadCachedPapers(for: topic)
                self.tabStates[.topics]?.papers = papers
            } catch {
                if !Task.isCancelled {
                    self.showToast("Failed to populate topic: \(error.localizedDescription)")
                    self.tabStates[.topics]?.loadState = .loaded
                }
            }
        }
    }

    /// Check for new papers in the active topic.
    func checkForNewTopicPapers() async -> Int {
        guard let topic = activeTopic else { return 0 }
        do {
            let newCount = try await topicRepository.checkForNewPapers(topic)
            if newCount > 0 {
                let papers = topicRepository.loadCachedPapers(for: topic)
                tabStates[.topics]?.papers = papers
            }
            return newCount
        } catch {
            return 0
        }
    }

    // MARK: - Toast

    private var toastTask: Task<Void, Never>?

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastError = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if toastError == message {
                toastError = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toastError = nil
    }

    // MARK: - Search

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try await paperRepository.searchPapers(query: searchQuery, page: 0)
        } catch {
            searchResults = []
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    // MARK: - Summary Retrieval

    func getCachedOrStoredSummary(for paper: Paper, style: SummaryStyle) -> String? {
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: style)

        if let streaming = streamingContent[requestId], !streaming.isEmpty {
            return streaming
        }

        if let completed = completedSummaries[requestId] {
            return completed
        }

        if let summary = paper.summary(for: style), summary.isComplete {
            return summary.content
        }

        return cloudStore.getSummary(paperId: paper.id, style: style)
    }

    // MARK: - Summarization (via Queue)

    func selectedStyle(for paper: Paper) -> SummaryStyle {
        selectedStyles[paper.id] ?? .tldr
    }

    func setSelectedStyle(_ style: SummaryStyle, for paper: Paper) {
        selectedStyles[paper.id] = style

        if getCachedOrStoredSummary(for: paper, style: style) != nil {
            return
        }

        enqueueSummary(for: paper, style: style, priority: .critical)
    }

    func isSummarizing(_ paper: Paper) -> Bool {
        let style = selectedStyle(for: paper)
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: style)
        return summarizingPapers.contains(requestId)
    }

    func currentStreamingContent(for paper: Paper) -> String? {
        let style = selectedStyle(for: paper)
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: style)
        return streamingContent[requestId]
    }

    private func enqueueSummary(for paper: Paper, style: SummaryStyle, priority: SummarizationPriority) {
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: style)

        if getCachedOrStoredSummary(for: paper, style: style) != nil {
            return
        }

        summarizingPapers.insert(requestId)

        Task {
            await summarizationQueue.enqueue(
                paperId: paper.id,
                paperTitle: paper.title,
                paperAbstract: paper.abstract,
                style: style,
                priority: priority
            )
        }
    }

    // MARK: - Smart Queue Management

    private func queueSummariesForVisiblePaper(at index: Int) async {
        let p = papers
        guard index >= 0 && index < p.count else { return }

        let visiblePaper = p[index]
        let activeStyle = selectedStyle(for: visiblePaper)

        enqueueSummary(for: visiblePaper, style: activeStyle, priority: .critical)

        for style in SummaryStyle.quickAccessStyles where style != activeStyle {
            enqueueSummary(for: visiblePaper, style: style, priority: .high)
        }

        if index + 1 < p.count {
            let nextPaper = p[index + 1]
            enqueueSummary(for: nextPaper, style: .tldr, priority: .medium)
        }

        if index + 2 < p.count {
            let futurePaper = p[index + 2]
            enqueueSummary(for: futurePaper, style: .tldr, priority: .low)
        }

        if index > 0 {
            let previousPaper = p[index - 1]
            await summarizationQueue.demotePaper(paperId: previousPaper.id, to: .low)
        }
    }

    // MARK: - SummarizationQueueDelegate

    nonisolated func summarizationQueue(_ queue: SummarizationQueue, didComplete requestId: String, result: SummarizationResult) {
        Task { @MainActor in
            summarizingPapers.remove(requestId)
            streamingContent.removeValue(forKey: requestId)

            switch result {
            case .success(let content):
                completedSummaries[requestId] = content

                if let lastUnderscore = requestId.lastIndex(of: "_") {
                    let paperId = String(requestId[requestId.startIndex..<lastUnderscore])
                    let styleRaw = String(requestId[requestId.index(after: lastUnderscore)...])
                    if let style = SummaryStyle(rawValue: styleRaw) {
                        cloudStore.saveSummary(paperId: paperId, style: style, content: content)
                    }
                }

            case .failure(let error):
                print("Summarization failed for \(requestId): \(error)")

            case .cancelled:
                print("Summarization cancelled for \(requestId)")
            }
        }
    }

    nonisolated func summarizationQueue(_ queue: SummarizationQueue, didUpdateProgress requestId: String, content: String) {
        Task { @MainActor in
            streamingContent[requestId] = content
        }
    }

    // MARK: - Paper Actions

    func openPDF(for paper: Paper) -> URL? {
        paper.pdfURLObject
    }

    func openAbstract(for paper: Paper) -> URL? {
        paper.abstractURLObject
    }

    func sharePaper(_ paper: Paper) -> [Any] {
        var items: [Any] = []
        items.append("\(paper.title)\n\nBy \(paper.authors.shortDisplayString)")
        if let url = paper.abstractURLObject {
            items.append(url)
        }
        return items
    }

    // MARK: - Cleanup

    func cleanupOldPapers() async {
        await paperRepository.cleanupOldPapers(retentionDays: preferencesStore.paperRetentionDays)
    }
}

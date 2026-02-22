//
//  FeedViewModelTests.swift
//  PapercutTests
//

import Testing
import Foundation
import SwiftData
@testable import Papercut

// MARK: - Mock ArXiv Service

final class MockArXivService: ArXivServiceProtocol, @unchecked Sendable {
    var papers: [Paper] = []
    var totalResults: Int = 0
    var shouldFail = false
    var failError: Error = ArXivServiceError.httpError(statusCode: 500)
    var fetchCallCount = 0
    var searchCallCount = 0
    var trendingCallCount = 0

    func fetchPapers(categories: [String], page: Int, pageSize: Int, sortBy: ArXivSortBy) async throws -> ArXivResponse {
        fetchCallCount += 1
        if shouldFail { throw failError }
        return ArXivResponse(papers: papers, totalResults: totalResults, hasMore: papers.count < totalResults)
    }

    func searchPapers(query: String, page: Int, pageSize: Int, sortBy: ArXivSortBy, sortOrder: ArXivSortOrder = .descending, categories: [String] = []) async throws -> ArXivResponse {
        searchCallCount += 1
        if shouldFail { throw failError }
        let filtered = papers.filter { $0.title.lowercased().contains(query.lowercased()) }
        return ArXivResponse(papers: filtered, totalResults: filtered.count, hasMore: false)
    }

    func fetchTrending(categories: [String], limit: Int) async throws -> ArXivResponse {
        trendingCallCount += 1
        if shouldFail { throw failError }
        return ArXivResponse(papers: papers, totalResults: papers.count, hasMore: false)
    }

    func fetchPaper(id: String) async throws -> Paper? {
        if shouldFail { throw failError }
        return papers.first { $0.id == id }
    }
}

// MARK: - Mock Side Effect Executor

/// Executor that synchronously captures effects and returns pre-configured results
final class MockSideEffectExecutor: SideEffectExecutor, @unchecked Sendable {
    var executedEffects: [FeedSideEffect] = []
    var resultToReturn: FeedEvent?
    var resultForEffect: (FeedSideEffect) -> FeedEvent? = { _ in nil }

    @MainActor func execute(
        _ effect: FeedSideEffect,
        for tab: FeedTab,
        categories: [String]
    ) async -> FeedEvent? {
        executedEffects.append(effect)
        return resultForEffect(effect) ?? resultToReturn
    }
}

// MARK: - Test Helpers

@MainActor
private func makeTestDependencies(
    mockExecutor: MockSideEffectExecutor? = nil
) -> (FeedViewModel, MockArXivService, PreferencesStore, MockSideEffectExecutor) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Paper.self, Summary.self, Topic.self, configurations: config)
    let modelContext = container.mainContext

    let mockArXiv = MockArXivService()
    let mockSummarization = MockSummarizationService()

    let defaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
    let prefsStore = PreferencesStore(userDefaults: defaults)

    let repository = PaperRepository(
        arXivService: mockArXiv,
        summarizationService: mockSummarization,
        modelContext: modelContext
    )

    let topicRepository = TopicRepository(
        modelContext: modelContext,
        arXivService: mockArXiv
    )

    let executor = mockExecutor ?? MockSideEffectExecutor()
    let viewModel = FeedViewModel(repository: repository, topicRepository: topicRepository, preferencesStore: prefsStore, executor: executor)
    return (viewModel, mockArXiv, prefsStore, executor)
}

/// Helper: load papers into a ViewModel's current tab state directly
@MainActor
private func loadPapersIntoVM(_ vm: FeedViewModel, papers: [Paper]) {
    vm.tabStates[vm.currentTab] = TabState(
        papers: papers,
        page: 0,
        scrollPosition: nil,
        loadState: .loaded,
        hasMore: false,
        lastFetchedAt: Date(),
        showNewPapersPill: false
    )
}

private func makeSamplePapers(count: Int) -> [Paper] {
    (0..<count).map { i in
        Paper(
            id: "paper_\(i)",
            title: "Paper \(i)",
            abstract: "Abstract for paper \(i)",
            authors: [Author(name: "Author \(i)")],
            categories: ["cs.AI"],
            publishedDate: Date(),
            updatedDate: Date(),
            pdfURL: "https://arxiv.org/pdf/2401.\(String(format: "%05d", i))v1",
            abstractURL: "https://arxiv.org/abs/2401.\(String(format: "%05d", i))"
        )
    }
}

@Suite(.serialized)
struct FeedViewModelTests {

    // MARK: - Initial State

    @MainActor
    @Test func initialState_isEmpty() {
        let (vm, _, _, _) = makeTestDependencies()
        #expect(vm.papers.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingMore == false)
        #expect(vm.error == nil)
        #expect(vm.currentTab == .latest)
        #expect(vm.currentPaperIndex == 0)
        #expect(vm.searchQuery.isEmpty)
        #expect(vm.toastError == nil)
        #expect(vm.isRefreshingInBackground == false)
    }

    // MARK: - hasCategories

    @MainActor
    @Test func hasCategories_falseWhenEmpty() {
        let (vm, _, _, _) = makeTestDependencies()
        #expect(vm.hasCategories == false)
    }

    @MainActor
    @Test func hasCategories_trueWhenCategoriesExist() {
        let (vm, _, prefs, _) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        #expect(vm.hasCategories == true)
    }

    // MARK: - loadPapers

    @MainActor
    @Test func loadPapers_noCategories_returnsEmpty() async {
        let (vm, _, _, _) = makeTestDependencies()
        await vm.loadPapers()

        #expect(vm.papers.isEmpty)
        #expect(vm.error == nil)
    }

    @MainActor
    @Test func loadPapers_withCategories_fetchesPapers() async {
        let samplePapers = makeSamplePapers(count: 5)
        let executor = MockSideEffectExecutor()
        executor.resultForEffect = { effect in
            if case .fetch = effect {
                return .fetchSucceeded(papers: samplePapers, hasMore: false)
            }
            return nil
        }
        let (vm, _, prefs, _) = makeTestDependencies(mockExecutor: executor)
        prefs.followCategory("cs.AI")

        await vm.loadPapers()
        // Allow the async Task to complete
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.papers.count == 5)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @MainActor
    @Test func loadPapers_apiError_noExistingPapers_setsError() async {
        let executor = MockSideEffectExecutor()
        executor.resultForEffect = { effect in
            if case .fetch = effect {
                return .fetchFailed(error: "Network error")
            }
            return nil
        }
        let (vm, _, prefs, _) = makeTestDependencies(mockExecutor: executor)
        prefs.followCategory("cs.AI")

        await vm.loadPapers()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.papers.isEmpty)
        #expect(vm.error != nil)
    }

    @MainActor
    @Test func loadPapers_apiError_withExistingPapers_showsToast() async {
        let samplePapers = makeSamplePapers(count: 3)
        var shouldFail = false
        let executor = MockSideEffectExecutor()
        executor.resultForEffect = { effect in
            if case .fetch = effect {
                if shouldFail {
                    return .fetchFailed(error: "Network error")
                }
                return .fetchSucceeded(papers: samplePapers, hasMore: false)
            }
            return nil
        }
        let (vm, _, prefs, _) = makeTestDependencies(mockExecutor: executor)
        prefs.followCategory("cs.AI")

        // First load succeeds
        await vm.loadPapers()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(vm.papers.count == 3)

        // Second load fails (refresh)
        shouldFail = true
        await vm.loadPapers(forceRefresh: true)
        try? await Task.sleep(for: .milliseconds(50))

        // Should still have papers, show toast instead of error
        #expect(vm.papers.count == 3)
        #expect(vm.error == nil)
        #expect(vm.toastError != nil)
    }

    // MARK: - displayPapers

    @MainActor
    @Test func displayPapers_returnsSearchResultsWhenSearching() {
        let (vm, _, _, _) = makeTestDependencies()
        vm.isSearching = true
        vm.searchQuery = "test"
        // searchResults is empty by default
        #expect(vm.displayPapers.isEmpty)
    }

    @MainActor
    @Test func displayPapers_returnsPapersWhenNotSearching() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 2)
        loadPapersIntoVM(vm, papers: papers)

        #expect(vm.displayPapers.count == 2)
    }

    // MARK: - currentPaper

    @MainActor
    @Test func currentPaper_nilWhenEmpty() {
        let (vm, _, _, _) = makeTestDependencies()
        #expect(vm.currentPaper == nil)
    }

    @MainActor
    @Test func currentPaper_returnsCorrectPaper() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 3)
        loadPapersIntoVM(vm, papers: papers)
        vm.currentPaperIndex = 1

        #expect(vm.currentPaper?.id == "paper_1")
    }

    @MainActor
    @Test func currentPaper_nilForOutOfBoundsIndex() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 2)
        loadPapersIntoVM(vm, papers: papers)
        vm.currentPaperIndex = 999

        #expect(vm.currentPaper == nil)
    }

    // MARK: - Tab Switching

    @MainActor
    @Test func switchTab_updatesCurrentTab() async {
        let (vm, _, _, _) = makeTestDependencies()

        await vm.switchTab(to: .trending)
        #expect(vm.currentTab == .trending)
        #expect(vm.currentPaperIndex == 0)
    }

    @MainActor
    @Test func switchTab_sameTab_noOp() async {
        let (vm, _, _, executor) = makeTestDependencies()

        await vm.switchTab(to: .latest) // Same as default

        // No effects should have been executed
        #expect(executor.executedEffects.isEmpty)
    }

    // MARK: - Toast

    @MainActor
    @Test func dismissToast_clearsMessage() {
        let (vm, _, _, _) = makeTestDependencies()
        vm.dismissToast()
        #expect(vm.toastError == nil)
    }

    // MARK: - Search

    @MainActor
    @Test func clearSearch_resetsSearchState() {
        let (vm, _, _, _) = makeTestDependencies()
        vm.searchQuery = "test"
        vm.isSearching = true

        vm.clearSearch()

        #expect(vm.searchQuery.isEmpty)
        #expect(vm.isSearching == false)
    }

    // MARK: - Summary Style Selection

    @MainActor
    @Test func selectedStyle_defaultsToTldr() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        #expect(vm.selectedStyle(for: paper) == .tldr)
    }

    @MainActor
    @Test func setSelectedStyle_updatesStyle() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        vm.setSelectedStyle(.keyFindings, for: paper)
        #expect(vm.selectedStyle(for: paper) == .keyFindings)
    }

    // MARK: - Summarization State

    @MainActor
    @Test func isSummarizing_falseByDefault() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        #expect(vm.isSummarizing(paper) == false)
    }

    @MainActor
    @Test func currentStreamingContent_nilByDefault() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        #expect(vm.currentStreamingContent(for: paper) == nil)
    }

    // MARK: - Share Paper

    @MainActor
    @Test func sharePaper_returnsItems() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let items = vm.sharePaper(paper)
        #expect(!items.isEmpty)
        #expect(items.count >= 1)
    }

    // MARK: - URL Helpers

    @MainActor
    @Test func openPDF_returnsURL() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let url = vm.openPDF(for: paper)
        #expect(url != nil)
    }

    @MainActor
    @Test func openAbstract_returnsURL() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let url = vm.openAbstract(for: paper)
        #expect(url != nil)
    }

    // MARK: - Cached Summary Retrieval

    @MainActor
    @Test func getCachedOrStoredSummary_nilWhenNoneExist() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == nil)
    }

    @MainActor
    @Test func getCachedOrStoredSummary_returnsStreamingContent() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: .tldr)

        vm.streamingContent[requestId] = "Streaming..."

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == "Streaming...")
    }

    @MainActor
    @Test func getCachedOrStoredSummary_returnsCompletedSummary() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: .tldr)

        vm.completedSummaries[requestId] = "Completed summary"

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == "Completed summary")
    }

    @MainActor
    @Test func getCachedOrStoredSummary_streamingTakesPriorityOverCompleted() {
        let (vm, _, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: .tldr)

        vm.streamingContent[requestId] = "Still streaming"
        vm.completedSummaries[requestId] = "Already done"

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == "Still streaming")
    }

    // MARK: - Enabled Styles

    @MainActor
    @Test func enabledStyles_matchesPreferencesStore() {
        let (vm, _, prefs, _) = makeTestDependencies()
        #expect(vm.enabledStyles == prefs.enabledSummaryStyles)
    }

    // MARK: - FeedTab

    @Test func feedTab_allCases() {
        #expect(FeedTab.allCases.count == 4)
        #expect(FeedTab.latest.rawValue == "Latest")
        #expect(FeedTab.trending.rawValue == "Trending")
        #expect(FeedTab.saved.rawValue == "Saved")
        #expect(FeedTab.topics.rawValue == "Topics")
    }

    @Test func feedTab_iconNames() {
        #expect(FeedTab.latest.iconName == "clock.fill")
        #expect(FeedTab.trending.iconName == "flame.fill")
        #expect(FeedTab.saved.iconName == "bookmark.fill")
        #expect(FeedTab.topics.iconName == "text.magnifyingglass")
    }

    // MARK: - List Boundary Haptics

    @MainActor
    @Test func boundaryReached_nilByDefault() {
        let (vm, _, _, _) = makeTestDependencies()
        #expect(vm.lastBoundaryReached == nil)
    }

    @MainActor
    @Test func onPaperAppear_firstPaper_setsBoundaryToTop() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 5)
        loadPapersIntoVM(vm, papers: papers)

        vm.onPaperAppear(papers[0], at: 0)
        #expect(vm.lastBoundaryReached == .top)
    }

    @MainActor
    @Test func onPaperAppear_lastPaper_setsBoundaryToBottom() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 5)
        loadPapersIntoVM(vm, papers: papers)

        vm.onPaperAppear(papers[4], at: 4)
        #expect(vm.lastBoundaryReached == .bottom)
    }

    @MainActor
    @Test func onPaperAppear_middlePaper_clearsBoundary() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 5)
        loadPapersIntoVM(vm, papers: papers)

        vm.onPaperAppear(papers[0], at: 0)
        #expect(vm.lastBoundaryReached == .top)

        vm.onPaperAppear(papers[2], at: 2)
        #expect(vm.lastBoundaryReached == nil)
    }

    @MainActor
    @Test func onPaperAppear_singlePaper_setsBoundaryToTop() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 1)
        loadPapersIntoVM(vm, papers: papers)

        vm.onPaperAppear(papers[0], at: 0)
        // Single paper is both top and bottom, but top takes precedence
        #expect(vm.lastBoundaryReached == .top)
    }

    @MainActor
    @Test func clearBoundary_resetsToNil() {
        let (vm, _, _, _) = makeTestDependencies()
        let papers = makeSamplePapers(count: 5)
        loadPapersIntoVM(vm, papers: papers)

        vm.onPaperAppear(papers[0], at: 0)
        #expect(vm.lastBoundaryReached == .top)

        vm.clearBoundary()
        #expect(vm.lastBoundaryReached == nil)
    }
}

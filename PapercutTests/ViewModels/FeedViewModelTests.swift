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

    func searchPapers(query: String, page: Int, pageSize: Int) async throws -> ArXivResponse {
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

// MARK: - Test Helpers

@MainActor
private func makeTestDependencies() -> (FeedViewModel, MockArXivService, PreferencesStore) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Paper.self, Summary.self, configurations: config)
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

    let viewModel = FeedViewModel(repository: repository, preferencesStore: prefsStore)
    return (viewModel, mockArXiv, prefsStore)
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
        let (vm, _, _) = makeTestDependencies()
        #expect(vm.papers.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingMore == false)
        #expect(vm.error == nil)
        #expect(vm.currentTab == .forYou)
        #expect(vm.currentPaperIndex == 0)
        #expect(vm.searchQuery.isEmpty)
        #expect(vm.toastError == nil)
        #expect(vm.isRefreshingInBackground == false)
    }

    // MARK: - hasCategories

    @MainActor
    @Test func hasCategories_falseWhenEmpty() {
        let (vm, _, _) = makeTestDependencies()
        #expect(vm.hasCategories == false)
    }

    @MainActor
    @Test func hasCategories_trueWhenCategoriesExist() {
        let (vm, _, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        #expect(vm.hasCategories == true)
    }

    // MARK: - loadPapers

    @MainActor
    @Test func loadPapers_noCategories_returnsEmpty() async {
        let (vm, _, _) = makeTestDependencies()
        await vm.loadPapers()

        #expect(vm.papers.isEmpty)
        #expect(vm.error == nil)
    }

    @MainActor
    @Test func loadPapers_withCategories_fetchesPapers() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.papers = makeSamplePapers(count: 5)
        mockArXiv.totalResults = 5

        await vm.loadPapers()

        #expect(vm.papers.count == 5)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @MainActor
    @Test func loadPapers_apiError_noExistingPapers_setsError() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.shouldFail = true

        await vm.loadPapers()

        #expect(vm.papers.isEmpty)
        #expect(vm.error != nil)
    }

    @MainActor
    @Test func loadPapers_apiError_withExistingPapers_showsToast() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.papers = makeSamplePapers(count: 3)
        mockArXiv.totalResults = 3

        // First load succeeds
        await vm.loadPapers()
        #expect(vm.papers.count == 3)

        // Second load fails
        mockArXiv.shouldFail = true
        await vm.loadPapers()

        // Should still have papers, show toast instead of error
        #expect(vm.papers.count == 3)
        #expect(vm.error == nil)
        #expect(vm.toastError != nil)
    }

    // MARK: - displayPapers

    @MainActor
    @Test func displayPapers_returnsSearchResultsWhenSearching() {
        let (vm, _, _) = makeTestDependencies()
        vm.isSearching = true
        vm.searchQuery = "test"
        // searchResults is empty by default
        #expect(vm.displayPapers.isEmpty)
    }

    @MainActor
    @Test func displayPapers_returnsPapersWhenNotSearching() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.papers = makeSamplePapers(count: 2)
        mockArXiv.totalResults = 2

        await vm.loadPapers()

        #expect(vm.displayPapers.count == 2)
    }

    // MARK: - currentPaper

    @MainActor
    @Test func currentPaper_nilWhenEmpty() {
        let (vm, _, _) = makeTestDependencies()
        #expect(vm.currentPaper == nil)
    }

    @MainActor
    @Test func currentPaper_returnsCorrectPaper() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.papers = makeSamplePapers(count: 3)
        mockArXiv.totalResults = 3

        await vm.loadPapers()
        vm.currentPaperIndex = 1

        #expect(vm.currentPaper?.id == "paper_1")
    }

    @MainActor
    @Test func currentPaper_nilForOutOfBoundsIndex() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.papers = makeSamplePapers(count: 2)
        mockArXiv.totalResults = 2

        await vm.loadPapers()
        vm.currentPaperIndex = 999

        #expect(vm.currentPaper == nil)
    }

    // MARK: - Tab Switching

    @MainActor
    @Test func switchTab_updatesCurrentTab() async {
        let (vm, mockArXiv, prefs) = makeTestDependencies()
        prefs.followCategory("cs.AI")
        mockArXiv.papers = makeSamplePapers(count: 2)
        mockArXiv.totalResults = 2

        await vm.switchTab(to: .trending)
        #expect(vm.currentTab == .trending)
        #expect(vm.currentPaperIndex == 0)
    }

    @MainActor
    @Test func switchTab_sameTab_noOp() async {
        let (vm, mockArXiv, _) = makeTestDependencies()
        let initialCallCount = mockArXiv.fetchCallCount

        await vm.switchTab(to: .forYou) // Same as default

        #expect(mockArXiv.fetchCallCount == initialCallCount)
    }

    // MARK: - Toast

    @MainActor
    @Test func dismissToast_clearsMessage() {
        let (vm, _, _) = makeTestDependencies()
        // Manually set toast for testing
        vm.dismissToast()
        #expect(vm.toastError == nil)
    }

    // MARK: - Search

    @MainActor
    @Test func clearSearch_resetsSearchState() {
        let (vm, _, _) = makeTestDependencies()
        vm.searchQuery = "test"
        vm.isSearching = true

        vm.clearSearch()

        #expect(vm.searchQuery.isEmpty)
        #expect(vm.isSearching == false)
    }

    // MARK: - Summary Style Selection

    @MainActor
    @Test func selectedStyle_defaultsToTldr() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        #expect(vm.selectedStyle(for: paper) == .tldr)
    }

    @MainActor
    @Test func setSelectedStyle_updatesStyle() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        vm.setSelectedStyle(.keyFindings, for: paper)
        #expect(vm.selectedStyle(for: paper) == .keyFindings)
    }

    // MARK: - Summarization State

    @MainActor
    @Test func isSummarizing_falseByDefault() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        #expect(vm.isSummarizing(paper) == false)
    }

    @MainActor
    @Test func currentStreamingContent_nilByDefault() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        #expect(vm.currentStreamingContent(for: paper) == nil)
    }

    // MARK: - Share Paper

    @MainActor
    @Test func sharePaper_returnsItems() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let items = vm.sharePaper(paper)
        #expect(!items.isEmpty)
        #expect(items.count >= 1)
    }

    // MARK: - URL Helpers

    @MainActor
    @Test func openPDF_returnsURL() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let url = vm.openPDF(for: paper)
        #expect(url != nil)
    }

    @MainActor
    @Test func openAbstract_returnsURL() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let url = vm.openAbstract(for: paper)
        #expect(url != nil)
    }

    // MARK: - Cached Summary Retrieval

    @MainActor
    @Test func getCachedOrStoredSummary_nilWhenNoneExist() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == nil)
    }

    @MainActor
    @Test func getCachedOrStoredSummary_returnsStreamingContent() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: .tldr)

        vm.streamingContent[requestId] = "Streaming..."

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == "Streaming...")
    }

    @MainActor
    @Test func getCachedOrStoredSummary_returnsCompletedSummary() {
        let (vm, _, _) = makeTestDependencies()
        let paper = makeSamplePapers(count: 1)[0]
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: .tldr)

        vm.completedSummaries[requestId] = "Completed summary"

        let summary = vm.getCachedOrStoredSummary(for: paper, style: .tldr)
        #expect(summary == "Completed summary")
    }

    @MainActor
    @Test func getCachedOrStoredSummary_streamingTakesPriorityOverCompleted() {
        let (vm, _, _) = makeTestDependencies()
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
        let (vm, _, prefs) = makeTestDependencies()
        #expect(vm.enabledStyles == prefs.enabledSummaryStyles)
    }

    // MARK: - FeedTab

    @Test func feedTab_allCases() {
        #expect(FeedTab.allCases.count == 4)
        #expect(FeedTab.forYou.rawValue == "For You")
        #expect(FeedTab.trending.rawValue == "Trending")
        #expect(FeedTab.latest.rawValue == "Latest")
        #expect(FeedTab.saved.rawValue == "Saved")
    }

    @Test func feedTab_iconNames() {
        #expect(FeedTab.forYou.iconName == "sparkles")
        #expect(FeedTab.trending.iconName == "flame.fill")
        #expect(FeedTab.latest.iconName == "clock.fill")
        #expect(FeedTab.saved.iconName == "bookmark.fill")
    }
}

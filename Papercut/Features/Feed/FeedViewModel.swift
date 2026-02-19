//
//  FeedViewModel.swift
//  Papercut
//

import Foundation
import SwiftUI
import SwiftData

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case trending = "Trending"
    case latest = "Latest"
    case saved = "Saved"

    var iconName: String {
        switch self {
        case .forYou: return "sparkles"
        case .trending: return "flame.fill"
        case .latest: return "clock.fill"
        case .saved: return "bookmark.fill"
        }
    }
}

@Observable
@MainActor
final class FeedViewModel: SummarizationQueueDelegate {
    // MARK: - State
    private(set) var papers: [Paper] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: Error?
    private(set) var currentPage = 0

    /// Transient error shown as a toast, auto-dismissed
    private(set) var toastError: String?

    /// Whether a background refresh is in progress (non-blocking)
    private(set) var isRefreshingInBackground = false

    // Current feed state
    var currentTab: FeedTab = .forYou
    var currentPaperIndex: Int = 0

    // Search state
    var searchQuery = ""
    var isSearching = false
    private(set) var searchResults: [Paper] = []

    // Summarization state per paper (for UI updates)
    private(set) var summarizingPapers: Set<String> = []
    var streamingContent: [String: String] = [:]
    var selectedStyles: [String: SummaryStyle] = [:]
    var completedSummaries: [String: String] = [:] // requestId -> content

    // MARK: - Dependencies
    let paperRepository: PaperRepository
    private let preferencesStore: PreferencesStore
    private let cloudStore = CloudSummaryStore.shared
    private let summarizationQueue = SummarizationQueue.shared
    private let bookmarkStore = BookmarkStore.shared

    init(repository: PaperRepository, preferencesStore: PreferencesStore) {
        self.paperRepository = repository
        self.preferencesStore = preferencesStore

        // Configure the queue
        Task {
            await summarizationQueue.configure(
                service: SummarizationServiceFactory.create(),
                delegate: self
            )
        }
    }

    // MARK: - Computed Properties

    var hasCategories: Bool {
        !preferencesStore.followedCategories.isEmpty
    }

    var enabledStyles: Set<SummaryStyle> {
        preferencesStore.enabledSummaryStyles
    }

    var canLoadMore: Bool {
        currentTab != .saved && paperRepository.canLoadMore && !isLoadingMore
    }

    var currentPaper: Paper? {
        guard currentPaperIndex >= 0 && currentPaperIndex < papers.count else { return nil }
        return papers[currentPaperIndex]
    }

    var displayPapers: [Paper] {
        isSearching && !searchQuery.isEmpty ? searchResults : papers
    }

    // MARK: - Feed Actions

    func loadPapers(forceRefresh: Bool = false) async {
        // Saved tab doesn't need categories
        if currentTab != .saved && !hasCategories {
            papers = []
            return
        }

        let hadPapers = !papers.isEmpty
        error = nil

        // Handle Saved tab separately
        if currentTab == .saved {
            isLoading = papers.isEmpty
            await loadSavedPapers()
            isLoading = false
            return
        }

        // If we have no papers at all, show the loading spinner
        // If we already have papers, refresh silently in the background
        if !hadPapers {
            isLoading = true
        } else {
            isRefreshingInBackground = true
        }

        currentPage = 0

        if forceRefresh {
            paperRepository.resetPagination()
            await summarizationQueue.clearLowPriority()
        }

        do {
            let mode: FeedMode
            switch currentTab {
            case .forYou:
                mode = .trending
            case .trending:
                mode = .trending
            case .latest:
                mode = .latest
            case .saved:
                mode = .latest // Won't reach here
            }

            let fetchedPapers = try await paperRepository.fetchPapers(
                categories: preferencesStore.followedCategories,
                page: 0,
                forceRefresh: forceRefresh,
                mode: mode
            )
            papers = fetchedPapers
            error = nil

            // Queue summaries for visible papers
            if !papers.isEmpty {
                await queueSummariesForVisiblePaper(at: 0)
            }
        } catch {
            // If we already have papers, show a transient toast instead of blocking
            if hadPapers {
                showToast("Couldn't refresh — showing cached papers")
            } else {
                // No papers at all — try loading from local cache before showing error
                let cached = await loadCachedPapersForCurrentTab()
                if !cached.isEmpty {
                    papers = cached
                    showToast("Offline — showing cached papers")
                } else {
                    self.error = error
                }
            }
        }

        isLoading = false
        isRefreshingInBackground = false
    }

    /// Load papers from SwiftData cache without hitting the network
    private func loadCachedPapersForCurrentTab() async -> [Paper] {
        do {
            return try await paperRepository.fetchPapers(
                categories: preferencesStore.followedCategories,
                page: 0,
                forceRefresh: false,
                mode: currentTab == .latest ? .latest : .trending
            )
        } catch {
            return []
        }
    }

    private func loadSavedPapers() async {
        let savedIds = bookmarkStore.bookmarkedIds

        if savedIds.isEmpty {
            papers = []
            return
        }

        // Fetch saved papers from repository
        var savedPapers: [Paper] = []
        for id in savedIds {
            if let paper = await paperRepository.getPaper(id: id) {
                savedPapers.append(paper)
            }
        }

        // Sort by most recently saved (we don't track save date, so just reverse)
        papers = savedPapers
        error = nil

        if !papers.isEmpty {
            await queueSummariesForVisiblePaper(at: 0)
        }
    }

    func loadMorePapers() async {
        guard canLoadMore, !isLoading else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let morePapers = try await paperRepository.fetchPapers(
                categories: preferencesStore.followedCategories,
                page: currentPage,
                forceRefresh: false,
                mode: currentTab == .latest ? .latest : .trending
            )
            papers.append(contentsOf: morePapers)
        } catch {
            currentPage -= 1
            // Don't block — just show toast
            showToast("Couldn't load more papers")
        }

        isLoadingMore = false
    }

    func refresh() async {
        await loadPapers(forceRefresh: true)
    }

    func switchTab(to tab: FeedTab) async {
        guard currentTab != tab else { return }

        currentTab = tab
        currentPaperIndex = 0
        error = nil

        await summarizationQueue.clearAll()

        // Try to load cached papers for this tab immediately (non-blocking)
        let cached = await loadCachedPapersForCurrentTab()
        if !cached.isEmpty {
            papers = cached
            // Then refresh in background
            isRefreshingInBackground = true
            await loadPapers(forceRefresh: true)
        } else {
            // No cache — full loading state
            papers = []
            await loadPapers(forceRefresh: true)
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

        isLoading = true

        do {
            searchResults = try await paperRepository.searchPapers(query: searchQuery, page: 0)
        } catch {
            self.error = error
            searchResults = []
        }

        isLoading = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
    }

    // MARK: - Summary Retrieval

    func getCachedOrStoredSummary(for paper: Paper, style: SummaryStyle) -> String? {
        let requestId = SummarizationRequest.makeId(paperId: paper.id, style: style)

        // Check streaming content first (in-progress)
        if let streaming = streamingContent[requestId], !streaming.isEmpty {
            return streaming
        }

        // Check completed summaries (from queue)
        if let completed = completedSummaries[requestId] {
            return completed
        }

        // Check paper model
        if let summary = paper.summary(for: style), summary.isComplete {
            return summary.content
        }

        // Check local storage
        return cloudStore.getSummary(paperId: paper.id, style: style)
    }

    // MARK: - Summarization (via Queue)

    func selectedStyle(for paper: Paper) -> SummaryStyle {
        selectedStyles[paper.id] ?? .tldr
    }

    func setSelectedStyle(_ style: SummaryStyle, for paper: Paper) {
        selectedStyles[paper.id] = style

        // Check if already have this summary
        if getCachedOrStoredSummary(for: paper, style: style) != nil {
            return
        }

        // Queue with critical priority (user is actively viewing)
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

        // Skip if already have it
        if getCachedOrStoredSummary(for: paper, style: style) != nil {
            return
        }

        // Mark as summarizing
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

    func onPaperAppear(_ paper: Paper, at index: Int) {
        Task {
            await queueSummariesForVisiblePaper(at: index)
        }

        // Load more when near the end
        if papers.count > 0 && index >= max(0, papers.count - 3) {
            Task {
                await loadMorePapers()
            }
        }
    }

    private func queueSummariesForVisiblePaper(at index: Int) async {
        guard index >= 0 && index < papers.count else { return }

        let visiblePaper = papers[index]
        let activeStyle = selectedStyle(for: visiblePaper)

        // 1. CRITICAL: Current paper's active style
        enqueueSummary(for: visiblePaper, style: activeStyle, priority: .critical)

        // 2. HIGH: Current paper's other quick-access styles (user might tap)
        for style in SummaryStyle.quickAccessStyles where style != activeStyle {
            enqueueSummary(for: visiblePaper, style: style, priority: .high)
        }

        // 3. MEDIUM: Next paper's default style
        if index + 1 < papers.count {
            let nextPaper = papers[index + 1]
            enqueueSummary(for: nextPaper, style: .tldr, priority: .medium)
        }

        // 4. LOW: Paper after next (pre-computation)
        if index + 2 < papers.count {
            let futurePaper = papers[index + 2]
            enqueueSummary(for: futurePaper, style: .tldr, priority: .low)
        }

        // Demote previous papers to low priority
        if index > 0 {
            let previousPaper = papers[index - 1]
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

                // Save to local storage — parse requestId by finding the last "_"
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

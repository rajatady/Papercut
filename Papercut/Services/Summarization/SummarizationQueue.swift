//
//  SummarizationQueue.swift
//  Papercut
//
//  Priority queue for serialized summarization requests.
//  Ensures only one LanguageModelSession request runs at a time.
//

import Foundation

// MARK: - Priority Levels
enum SummarizationPriority: Int, Comparable {
    case critical = 0  // Currently visible paper's active style
    case high = 1      // Currently visible paper's other styles (user might tap)
    case medium = 2    // Next paper's default style (user might scroll)
    case low = 3       // Future papers (pre-computation)

    static func < (lhs: SummarizationPriority, rhs: SummarizationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Request
struct SummarizationRequest: Identifiable, Equatable {
    let id: String
    let paperId: String
    let paperTitle: String
    let paperAbstract: String
    let style: SummaryStyle
    var priority: SummarizationPriority
    let createdAt: Date

    static func == (lhs: SummarizationRequest, rhs: SummarizationRequest) -> Bool {
        lhs.id == rhs.id
    }

    static func makeId(paperId: String, style: SummaryStyle) -> String {
        "\(paperId)_\(style.rawValue)"
    }
}

// MARK: - Queue Result
enum SummarizationResult {
    case success(content: String)
    case failure(error: Error)
    case cancelled
}

// MARK: - Queue Delegate
protocol SummarizationQueueDelegate: AnyObject {
    @MainActor func summarizationQueue(_ queue: SummarizationQueue, didComplete requestId: String, result: SummarizationResult)
    @MainActor func summarizationQueue(_ queue: SummarizationQueue, didUpdateProgress requestId: String, content: String)
}

// MARK: - Summarization Queue (Actor for thread safety)
actor SummarizationQueue {

    // Singleton - but can also create instances for testing
    static let shared = SummarizationQueue()

    // MARK: - State
    private var queue: [SummarizationRequest] = []
    private var isProcessing = false
    private var currentRequestId: String?
    private var cancelledIds: Set<String> = []

    // Delegate for callbacks (weak reference via wrapper)
    private var delegateWrapper: DelegateWrapper?

    // Service
    private var summarizationService: (any SummarizationServiceProtocol)?

    // MARK: - Initialization

    init() {}

    func configure(service: any SummarizationServiceProtocol, delegate: SummarizationQueueDelegate?) {
        self.summarizationService = service
        self.delegateWrapper = delegate.map { DelegateWrapper($0) }
    }

    // MARK: - Public API

    /// Add a request to the queue
    func enqueue(
        paperId: String,
        paperTitle: String,
        paperAbstract: String,
        style: SummaryStyle,
        priority: SummarizationPriority
    ) {
        let requestId = SummarizationRequest.makeId(paperId: paperId, style: style)

        // Remove from cancelled if re-queued
        cancelledIds.remove(requestId)

        // Check if already in queue - update priority if higher
        if let existingIndex = queue.firstIndex(where: { $0.id == requestId }) {
            if priority < queue[existingIndex].priority {
                queue[existingIndex].priority = priority
                sortQueue()
            }
            return
        }

        // Check if currently processing this exact request
        if currentRequestId == requestId {
            return
        }

        let request = SummarizationRequest(
            id: requestId,
            paperId: paperId,
            paperTitle: paperTitle,
            paperAbstract: paperAbstract,
            style: style,
            priority: priority,
            createdAt: Date()
        )

        queue.append(request)
        sortQueue()

        // Start processing if not already
        if !isProcessing {
            Task {
                await processQueue()
            }
        }
    }

    /// Boost priority of a specific request (e.g., user scrolled to this paper)
    func boostPriority(paperId: String, style: SummaryStyle, to priority: SummarizationPriority) {
        let requestId = SummarizationRequest.makeId(paperId: paperId, style: style)

        if let index = queue.firstIndex(where: { $0.id == requestId }) {
            if priority < queue[index].priority {
                queue[index].priority = priority
                sortQueue()
            }
        }
    }

    /// Boost all requests for a paper (user is now viewing this paper)
    func boostPaper(paperId: String, activePriority: SummarizationPriority, otherStylesPriority: SummarizationPriority) {
        for index in queue.indices {
            if queue[index].paperId == paperId {
                // The first one found gets active priority, rest get other priority
                // Actually, we don't know which is "active" here, so boost all equally
                if otherStylesPriority < queue[index].priority {
                    queue[index].priority = otherStylesPriority
                }
            }
        }
        sortQueue()
    }

    /// Demote priority for papers no longer visible
    func demotePaper(paperId: String, to priority: SummarizationPriority) {
        for index in queue.indices {
            if queue[index].paperId == paperId && queue[index].priority < priority {
                queue[index].priority = priority
            }
        }
        sortQueue()
    }

    /// Cancel a specific request
    func cancel(paperId: String, style: SummaryStyle) {
        let requestId = SummarizationRequest.makeId(paperId: paperId, style: style)
        cancelledIds.insert(requestId)
        queue.removeAll { $0.id == requestId }
    }

    /// Cancel all requests for a paper
    func cancelPaper(paperId: String) {
        let idsToCancel = queue.filter { $0.paperId == paperId }.map { $0.id }
        cancelledIds.formUnion(idsToCancel)
        queue.removeAll { $0.paperId == paperId }
    }

    /// Clear all low priority requests
    func clearLowPriority() {
        queue.removeAll { $0.priority == .low }
    }

    /// Clear entire queue
    func clearAll() {
        let idsToCancel = queue.map { $0.id }
        cancelledIds.formUnion(idsToCancel)
        queue.removeAll()
    }

    /// Get current queue status
    func getStatus() -> (queueCount: Int, isProcessing: Bool, currentRequestId: String?) {
        return (queue.count, isProcessing, currentRequestId)
    }

    /// Check if a request is pending or processing
    func isPending(paperId: String, style: SummaryStyle) -> Bool {
        let requestId = SummarizationRequest.makeId(paperId: paperId, style: style)
        return currentRequestId == requestId || queue.contains { $0.id == requestId }
    }

    // MARK: - Private Methods

    private func sortQueue() {
        // Sort by priority first, then by creation time (FIFO within same priority)
        queue.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func processQueue() async {
        guard !isProcessing else { return }
        guard let service = summarizationService else {
            print("SummarizationQueue: No service configured")
            return
        }

        isProcessing = true

        while !queue.isEmpty {
            let request = queue.removeFirst()

            // Check if cancelled
            if cancelledIds.contains(request.id) {
                cancelledIds.remove(request.id)
                await notifyCompletion(requestId: request.id, result: .cancelled)
                continue
            }

            currentRequestId = request.id

            // Process the request
            do {
                // Use streaming for critical priority, non-streaming for others
                if request.priority == .critical {
                    // Stream the response
                    let stream = service.summarizeStreaming(
                        paper: makeTempPaper(from: request),
                        style: request.style
                    )

                    var finalContent = ""
                    for try await chunk in stream {
                        finalContent += chunk
                        await notifyProgress(requestId: request.id, content: finalContent)
                    }

                    await notifyCompletion(requestId: request.id, result: .success(content: finalContent))
                } else {
                    // Non-streaming for background requests
                    let content = try await service.summarize(
                        paper: makeTempPaper(from: request),
                        style: request.style
                    )
                    await notifyCompletion(requestId: request.id, result: .success(content: content))
                }
            } catch {
                await notifyCompletion(requestId: request.id, result: .failure(error: error))
            }

            currentRequestId = nil
        }

        isProcessing = false
    }

    private func makeTempPaper(from request: SummarizationRequest) -> Paper {
        // Create a minimal Paper object for the service
        Paper(
            id: request.paperId,
            title: request.paperTitle,
            abstract: request.paperAbstract,
            authors: [],
            categories: [],
            publishedDate: Date(),
            updatedDate: Date(),
            pdfURL: "",
            abstractURL: ""
        )
    }

    private func notifyCompletion(requestId: String, result: SummarizationResult) async {
        // Capture delegate reference while in actor context
        guard let delegate = delegateWrapper?.delegate else { return }

        // Dispatch to MainActor for UI updates
        await MainActor.run {
            delegate.summarizationQueue(self, didComplete: requestId, result: result)
        }
    }

    private func notifyProgress(requestId: String, content: String) async {
        // Capture delegate reference while in actor context
        guard let delegate = delegateWrapper?.delegate else { return }

        // Dispatch to MainActor for UI updates
        await MainActor.run {
            delegate.summarizationQueue(self, didUpdateProgress: requestId, content: content)
        }
    }
}

// MARK: - Delegate Wrapper (for weak reference in actor)
private final class DelegateWrapper: Sendable {
    weak var delegate: SummarizationQueueDelegate?

    init(_ delegate: SummarizationQueueDelegate) {
        self.delegate = delegate
    }
}

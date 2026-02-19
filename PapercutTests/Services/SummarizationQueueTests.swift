//
//  SummarizationQueueTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

// MARK: - Mock Summarization Service

final class MockSummarizationService: SummarizationServiceProtocol, @unchecked Sendable {
    var isAvailable: Bool { get async { true } }
    var summarizeDelay: TimeInterval = 0
    var shouldFail = false
    var summarizeCallCount = 0

    func summarize(paper: Paper, style: SummaryStyle) async throws -> String {
        summarizeCallCount += 1
        if shouldFail { throw SummarizationError.generationFailed("Mock failure") }
        if summarizeDelay > 0 { try? await Task.sleep(for: .seconds(summarizeDelay)) }
        return "Summary of \(paper.title) in \(style.displayName)"
    }

    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            if self.shouldFail {
                continuation.finish(throwing: SummarizationError.generationFailed("Mock failure"))
                return
            }
            continuation.yield("Partial...")
            continuation.yield("Full summary of \(paper.title)")
            continuation.finish()
        }
    }
}

// MARK: - Mock Delegate

@MainActor
final class MockQueueDelegate: SummarizationQueueDelegate {
    var completedResults: [(String, SummarizationResult)] = []
    var progressUpdates: [(String, String)] = []

    nonisolated func summarizationQueue(_ queue: SummarizationQueue, didComplete requestId: String, result: SummarizationResult) {
        Task { @MainActor in
            self.completedResults.append((requestId, result))
        }
    }

    nonisolated func summarizationQueue(_ queue: SummarizationQueue, didUpdateProgress requestId: String, content: String) {
        Task { @MainActor in
            self.progressUpdates.append((requestId, content))
        }
    }
}

@Suite(.serialized)
struct SummarizationQueueTests {

    // MARK: - SummarizationPriority

    @Test func priority_ordering() {
        #expect(SummarizationPriority.critical < SummarizationPriority.high)
        #expect(SummarizationPriority.high < SummarizationPriority.medium)
        #expect(SummarizationPriority.medium < SummarizationPriority.low)
    }

    @Test func priority_rawValues() {
        #expect(SummarizationPriority.critical.rawValue == 0)
        #expect(SummarizationPriority.high.rawValue == 1)
        #expect(SummarizationPriority.medium.rawValue == 2)
        #expect(SummarizationPriority.low.rawValue == 3)
    }

    // MARK: - SummarizationRequest

    @Test func request_makeId() {
        let id = SummarizationRequest.makeId(paperId: "paper1", style: .tldr)
        #expect(id == "paper1_tldr")
    }

    @Test func request_equatable() {
        let r1 = SummarizationRequest(
            id: "p1_tldr", paperId: "p1", paperTitle: "Title",
            paperAbstract: "Abstract", style: .tldr, priority: .critical, createdAt: Date()
        )
        let r2 = SummarizationRequest(
            id: "p1_tldr", paperId: "p1", paperTitle: "Different",
            paperAbstract: "Different", style: .tldr, priority: .low, createdAt: Date()
        )
        #expect(r1 == r2) // Equality based on id only
    }

    // MARK: - Queue Operations

    @Test func queue_initialStatus() async {
        let queue = SummarizationQueue()
        let status = await queue.getStatus()
        #expect(status.queueCount == 0)
        #expect(status.isProcessing == false)
        #expect(status.currentRequestId == nil)
    }

    @Test func queue_enqueue_addsToQueue() async {
        let queue = SummarizationQueue()
        // Don't configure a service, so it won't process
        await queue.enqueue(
            paperId: "p1", paperTitle: "Title", paperAbstract: "Abstract",
            style: .tldr, priority: .medium
        )
        let isPending = await queue.isPending(paperId: "p1", style: .tldr)
        #expect(isPending == true)
    }

    @Test func queue_enqueue_duplicateUpdatesHigherPriority() async {
        let queue = SummarizationQueue()
        await queue.enqueue(
            paperId: "p1", paperTitle: "Title", paperAbstract: "Abstract",
            style: .tldr, priority: .low
        )
        // Re-enqueue with higher priority
        await queue.enqueue(
            paperId: "p1", paperTitle: "Title", paperAbstract: "Abstract",
            style: .tldr, priority: .critical
        )
        let status = await queue.getStatus()
        #expect(status.queueCount == 1) // Should still be 1, not 2
    }

    @Test func queue_cancel_removesFromQueue() async {
        let queue = SummarizationQueue()
        await queue.enqueue(
            paperId: "p1", paperTitle: "Title", paperAbstract: "Abstract",
            style: .tldr, priority: .medium
        )
        await queue.cancel(paperId: "p1", style: .tldr)

        let isPending = await queue.isPending(paperId: "p1", style: .tldr)
        #expect(isPending == false)
    }

    @Test func queue_cancelPaper_removesAllStylesForPaper() async {
        let queue = SummarizationQueue()
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .medium)
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .keyFindings, priority: .medium)
        await queue.enqueue(paperId: "p2", paperTitle: "T2", paperAbstract: "A2", style: .tldr, priority: .medium)

        await queue.cancelPaper(paperId: "p1")

        #expect(await queue.isPending(paperId: "p1", style: .tldr) == false)
        #expect(await queue.isPending(paperId: "p1", style: .keyFindings) == false)
        #expect(await queue.isPending(paperId: "p2", style: .tldr) == true)
    }

    @Test func queue_clearLowPriority_removesOnlyLow() async {
        let queue = SummarizationQueue()
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .critical)
        await queue.enqueue(paperId: "p2", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .low)

        await queue.clearLowPriority()

        #expect(await queue.isPending(paperId: "p1", style: .tldr) == true)
        #expect(await queue.isPending(paperId: "p2", style: .tldr) == false)
    }

    @Test func queue_clearAll_emptiesQueue() async {
        let queue = SummarizationQueue()
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .critical)
        await queue.enqueue(paperId: "p2", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .medium)

        await queue.clearAll()

        let status = await queue.getStatus()
        #expect(status.queueCount == 0)
    }

    // MARK: - Priority Boost/Demote

    @Test func queue_boostPriority_upgradesPriority() async {
        let queue = SummarizationQueue()
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .low)
        await queue.boostPriority(paperId: "p1", style: .tldr, to: .critical)

        // The request should still be pending (just with different priority)
        #expect(await queue.isPending(paperId: "p1", style: .tldr) == true)
    }

    @Test func queue_demotePaper_lowersAllPriorities() async {
        let queue = SummarizationQueue()
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .tldr, priority: .critical)
        await queue.enqueue(paperId: "p1", paperTitle: "T", paperAbstract: "A", style: .keyFindings, priority: .high)

        await queue.demotePaper(paperId: "p1", to: .low)

        // Requests should still be in queue
        #expect(await queue.isPending(paperId: "p1", style: .tldr) == true)
        #expect(await queue.isPending(paperId: "p1", style: .keyFindings) == true)
    }
}

// MARK: - SummarizationResult Tests

@Suite(.serialized)
struct SummarizationResultTests {

    @Test func success_carriesContent() {
        let result = SummarizationResult.success(content: "A summary")
        if case .success(let content) = result {
            #expect(content == "A summary")
        } else {
            Issue.record("Expected success")
        }
    }

    @Test func failure_carriesError() {
        let error = SummarizationError.modelUnavailable
        let result = SummarizationResult.failure(error: error)
        if case .failure(let e) = result {
            #expect(e is SummarizationError)
        } else {
            Issue.record("Expected failure")
        }
    }

    @Test func cancelled_isRecognized() {
        let result = SummarizationResult.cancelled
        if case .cancelled = result {
            // pass
        } else {
            Issue.record("Expected cancelled")
        }
    }
}

// MARK: - SummarizationError Tests

@Suite(.serialized)
struct SummarizationErrorTests {

    @Test func modelUnavailable_hasDescription() {
        let error = SummarizationError.modelUnavailable
        #expect(error.errorDescription?.contains("not available") == true)
        #expect(error.recoverySuggestion != nil)
    }

    @Test func generationFailed_includesReason() {
        let error = SummarizationError.generationFailed("timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
        #expect(error.recoverySuggestion != nil)
    }
}

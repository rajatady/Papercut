//
//  SummarizationService.swift
//  Papercut
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

protocol SummarizationServiceProtocol: Sendable {
    func summarize(paper: Paper, style: SummaryStyle) async throws -> String
    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error>
    var isAvailable: Bool { get async }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
final class SummarizationService: SummarizationServiceProtocol, @unchecked Sendable {
    private var session: LanguageModelSession?

    init() {}

    // MARK: - Availability Check

    var isAvailable: Bool {
        get async {
            do {
                let availability = SystemLanguageModel.default.availability
                switch availability {
                case .available:
                    return true
                case .unavailable:
                    return false
                @unknown default:
                    return false
                }
            }
        }
    }

    // MARK: - Session Management

    private func getOrCreateSession() async throws -> LanguageModelSession {
        if let existingSession = session {
            return existingSession
        }

        let newSession = LanguageModelSession(
            instructions: SummarizationPrompts.systemPrompt()
        )
        session = newSession
        return newSession
    }

    // MARK: - Summarization

    func summarize(paper: Paper, style: SummaryStyle) async throws -> String {
        guard await isAvailable else {
            throw SummarizationError.modelUnavailable
        }

        let session = try await getOrCreateSession()
        let prompt = SummarizationPrompts.prompt(
            for: style,
            title: paper.title,
            abstract: paper.abstract
        )

        let response = try await session.respond(to: prompt)
        return response.content
    }

    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard await self.isAvailable else {
                        throw SummarizationError.modelUnavailable
                    }

                    let session = try await self.getOrCreateSession()
                    let prompt = SummarizationPrompts.prompt(
                        for: style,
                        title: paper.title,
                        abstract: paper.abstract
                    )

                    let stream = session.streamResponse(to: prompt)

                    for try await partialResponse in stream {
                        continuation.yield(partialResponse.content)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Reset

    func resetSession() {
        session = nil
    }
}
#endif

// MARK: - Fallback Service for older iOS versions
final class FallbackSummarizationService: SummarizationServiceProtocol {
    var isAvailable: Bool {
        get async { false }
    }

    func summarize(paper: Paper, style: SummaryStyle) async throws -> String {
        throw SummarizationError.modelUnavailable
    }

    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: SummarizationError.modelUnavailable)
        }
    }
}

// MARK: - Factory
enum SummarizationServiceFactory {
    @MainActor
    static func create() -> any SummarizationServiceProtocol {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SummarizationService()
        } else {
            return FallbackSummarizationService()
        }
        #else
        return FallbackSummarizationService()
        #endif
    }
}

// MARK: - Errors
enum SummarizationError: Error, LocalizedError {
    case modelUnavailable
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "On-device AI model is not available. Please ensure you're running iOS 26 or later on a supported device."
        case .generationFailed(let reason):
            return "Summary generation failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelUnavailable:
            return "Try updating to the latest iOS version or using a newer device."
        case .generationFailed:
            return "Try again or select a different summary style."
        }
    }
}

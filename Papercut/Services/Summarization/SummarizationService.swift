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
    init() {}

    // MARK: - Availability Check

    var isAvailable: Bool {
        get async {
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

    // MARK: - Fresh Session Per Call
    // Each call gets a fresh session to avoid context accumulation.
    // The on-device model has a 4096 token limit — reusing sessions
    // causes prior conversation to eat into that budget.

    private func freshSession() -> LanguageModelSession {
        LanguageModelSession(instructions: SummarizationPrompts.systemPrompt())
    }

    // MARK: - Structured Summarization

    func summarize(paper: Paper, style: SummaryStyle) async throws -> String {
        guard await isAvailable else {
            throw SummarizationError.modelUnavailable
        }

        let prompt = SummarizationPrompts.prompt(
            for: style,
            title: paper.title,
            abstract: paper.abstract
        )

        do {
            return try await generateStructured(
                session: freshSession(), prompt: prompt, style: style
            )
        } catch {
            // If context window exceeded, retry with aggressively truncated abstract
            if isContextWindowError(error) {
                let shortPrompt = SummarizationPrompts.prompt(
                    for: style,
                    title: paper.title,
                    abstract: String(paper.abstract.prefix(2000))
                )
                return try await generateStructured(
                    session: freshSession(), prompt: shortPrompt, style: style
                )
            }
            throw error
        }
    }

    /// Use @Generable schemas for constrained output per style
    private func generateStructured(
        session: LanguageModelSession,
        prompt: String,
        style: SummaryStyle
    ) async throws -> String {
        switch style {
        case .tldr:
            let response = try await session.respond(to: prompt, generating: TLDROutput.self)
            return SummarizationPrompts.format(response.content)
        case .keyFindings:
            let response = try await session.respond(to: prompt, generating: KeyFindingsOutput.self)
            return SummarizationPrompts.format(response.content)
        case .mathExplained:
            let response = try await session.respond(to: prompt, generating: MathExplainedOutput.self)
            return SummarizationPrompts.format(response.content)
        case .codeExplained:
            let response = try await session.respond(to: prompt, generating: CodeExplainedOutput.self)
            return SummarizationPrompts.format(response.content)
        case .methodology:
            let response = try await session.respond(to: prompt, generating: MethodologyOutput.self)
            return SummarizationPrompts.format(response.content)
        case .implications:
            let response = try await session.respond(to: prompt, generating: ImplicationsOutput.self)
            return SummarizationPrompts.format(response.content)
        case .simpleExplanation:
            let response = try await session.respond(to: prompt, generating: SimpleExplanationOutput.self)
            return SummarizationPrompts.format(response.content)
        }
    }

    // MARK: - Context Window Error Detection

    private func isContextWindowError(_ error: Error) -> Bool {
        String(describing: error).contains("exceededContextWindowSize")
    }

    // MARK: - Streaming

    func summarizeStreaming(paper: Paper, style: SummaryStyle) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard await self.isAvailable else {
                        throw SummarizationError.modelUnavailable
                    }

                    // Structured generation returns complete output
                    let result = try await self.summarize(paper: paper, style: style)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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

//
//  SummarizationPrompts.swift
//  Papercut
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Output Schemas

@available(iOS 26.0, *)
@Generable
struct TLDROutput {
    @Guide(description: "The problem or goal the paper addresses, in one sentence. Plain text only.")
    let problem: String
    @Guide(description: "What the paper achieved or found, in one sentence. Plain text only.")
    let result: String
}

@available(iOS 26.0, *)
@Generable
struct KeyFindingsOutput {
    @Guide(description: "The single most important finding. One sentence, plain text.")
    let finding1: String
    @Guide(description: "The second most important finding. One sentence, plain text.")
    let finding2: String
    @Guide(description: "The third most important finding. One sentence, plain text.")
    let finding3: String
}

@available(iOS 26.0, *)
@Generable
struct MathExplainedOutput {
    @Guide(description: "The core mathematical approach in one sentence. Plain text, no LaTeX.")
    let coreIdea: String
    @Guide(description: "Explain 1-2 key equations in plain English: what goes in, what comes out, why it matters. No symbols or LaTeX.")
    let keyEquations: String
    @Guide(description: "A simple analogy or real-world example that captures the mathematical intuition.")
    let intuition: String
}

@available(iOS 26.0, *)
@Generable
struct CodeExplainedOutput {
    @Guide(description: "What the algorithm or computational method does, in one sentence.")
    let overview: String
    @Guide(description: "Step 1 of the algorithm. One sentence.")
    let step1: String
    @Guide(description: "Step 2 of the algorithm. One sentence.")
    let step2: String
    @Guide(description: "Step 3 of the algorithm. One sentence.")
    let step3: String
    @Guide(description: "Time/space complexity if mentioned, otherwise 'Not specified'.")
    let complexity: String
    @Guide(description: "Frameworks, languages, or tools mentioned. If none, say 'Not specified'.")
    let tools: String
}

@available(iOS 26.0, *)
@Generable
struct MethodologyOutput {
    @Guide(description: "What data or tools they used. One sentence under 25 words.")
    let dataAndTools: String
    @Guide(description: "Their approach or technique. One sentence under 25 words.")
    let approach: String
    @Guide(description: "How they validated results. One sentence under 25 words.")
    let validation: String
}

@available(iOS 26.0, *)
@Generable
struct ImplicationsOutput {
    @Guide(description: "One specific real-world application or consequence of this work. Plain text, one sentence.")
    let application: String
    @Guide(description: "Why a researcher or engineer should care about this. Plain text, one sentence.")
    let whyCare: String
}

@available(iOS 26.0, *)
@Generable
struct SimpleExplanationOutput {
    @Guide(description: "Explain this paper like the reader is a curious 10-year-old. Use a fun analogy. No jargon. 2-3 sentences max. Start with 'Imagine' or 'You know how'.")
    let explanation: String
}

#endif

// MARK: - Prompt Builder

enum SummarizationPrompts {
    // 4096 token context window. Reserve ~200 for system prompt,
    // ~100 for instructions, ~300 for schema overhead, ~400 for response.
    // Leaves ~3000 tokens ≈ 4500 chars for title + abstract.
    // Title is typically ~100-200 chars, so cap abstract at ~4000.
    private static let maxAbstractCharacters = 4000

    private static func truncateIfNeeded(_ abstract: String) -> String {
        guard abstract.count > maxAbstractCharacters else { return abstract }
        let truncated = String(abstract.prefix(maxAbstractCharacters))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + " [truncated]"
        }
        return truncated + " [truncated]"
    }

    static func prompt(for style: SummaryStyle, title: String, abstract: String) -> String {
        let safeAbstract = truncateIfNeeded(abstract)

        let context = """
        Paper title: \(title)

        Abstract: \(safeAbstract)
        """

        let instruction: String
        switch style {
        case .tldr:
            instruction = "Summarize this paper. Identify the problem and the result."
        case .keyFindings:
            instruction = "Identify the three most important findings from this paper."
        case .mathExplained:
            instruction = "Explain the mathematical concepts in this paper for someone who knows basic algebra."
        case .codeExplained:
            instruction = "Explain the algorithms and computational methods in this paper."
        case .methodology:
            instruction = "Describe how the researchers conducted this study."
        case .implications:
            instruction = "Explain the real-world applications and significance of this paper."
        case .simpleExplanation:
            instruction = "Explain this paper in simple terms a child could understand."
        }

        return "\(instruction)\n\n\(context)"
    }

    static func systemPrompt() -> String {
        """
        You are a research paper explainer. Rules:
        - Be accurate. Never invent details not in the abstract.
        - Write plain text only. No markdown, no bold, no italic, no headers, no bullet characters, no emojis, no special formatting.
        - Be concise. Every sentence must earn its place.
        - If something is not in the abstract, say so briefly.
        """
    }

    // MARK: - Formatting Structured Output into Display Text

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func format(_ output: TLDROutput) -> String {
        "\(output.problem) \(output.result)"
    }

    @available(iOS 26.0, *)
    static func format(_ output: KeyFindingsOutput) -> String {
        """
        \(output.finding1)

        \(output.finding2)

        \(output.finding3)
        """
    }

    @available(iOS 26.0, *)
    static func format(_ output: MathExplainedOutput) -> String {
        """
        Core idea: \(output.coreIdea)

        Key equations: \(output.keyEquations)

        Intuition: \(output.intuition)
        """
    }

    @available(iOS 26.0, *)
    static func format(_ output: CodeExplainedOutput) -> String {
        """
        \(output.overview)

        Steps:
        1. \(output.step1)
        2. \(output.step2)
        3. \(output.step3)

        Complexity: \(output.complexity)
        Tools: \(output.tools)
        """
    }

    @available(iOS 26.0, *)
    static func format(_ output: MethodologyOutput) -> String {
        """
        Data and tools: \(output.dataAndTools)

        Approach: \(output.approach)

        Validation: \(output.validation)
        """
    }

    @available(iOS 26.0, *)
    static func format(_ output: ImplicationsOutput) -> String {
        """
        \(output.application)

        \(output.whyCare)
        """
    }

    @available(iOS 26.0, *)
    static func format(_ output: SimpleExplanationOutput) -> String {
        output.explanation
    }
    #endif
}

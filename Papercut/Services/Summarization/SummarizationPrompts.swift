//
//  SummarizationPrompts.swift
//  Papercut
//

import Foundation

enum SummarizationPrompts {
    // Max tokens for context window is 4096
    // Reserve: ~100 for system, ~200 for style instructions, ~500 for response
    // Leaving ~3000 tokens for title + abstract
    // Roughly 3-4 chars per token, so limit abstract to ~8000 chars to be safe
    private static let maxAbstractCharacters = 8000

    /// Truncate abstract if it's too long to fit in context window
    private static func truncateIfNeeded(_ abstract: String) -> String {
        guard abstract.count > maxAbstractCharacters else { return abstract }

        // Truncate at word boundary
        let truncated = String(abstract.prefix(maxAbstractCharacters))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "... [truncated for length]"
        }
        return truncated + "... [truncated for length]"
    }

    static func prompt(for style: SummaryStyle, title: String, abstract: String) -> String {
        let safeAbstract = truncateIfNeeded(abstract)

        let baseContext = """
        Research Paper:
        Title: \(title)
        Abstract: \(safeAbstract)

        """

        let styleInstructions: String

        switch style {
        case .tldr:
            styleInstructions = """
            Give me a TL;DR in exactly 2 sentences:
            1. What's the problem/goal?
            2. What did they achieve?

            Be punchy and direct. No fluff.
            """

        case .keyFindings:
            styleInstructions = """
            List the 3-4 most important findings as bullet points.
            Use • for each point.
            Each point should be one clear sentence.
            Focus on what's NEW and SURPRISING.
            """

        case .mathExplained:
            styleInstructions = """
            Explain the key mathematical concepts in this paper for someone who knows basic algebra but not advanced math.

            Format your response as:
            🔢 **Core Idea**: [One sentence explaining the main mathematical approach]

            📐 **Key Equations**: [Explain 1-2 important formulas in plain English - what goes in, what comes out, why it matters]

            🎯 **Intuition**: [A simple analogy or real-world example that captures the math]

            If there's no significant math, say "This paper is primarily conceptual/experimental with minimal novel mathematics."
            """

        case .codeExplained:
            styleInstructions = """
            Explain any algorithms, code, or computational methods in this paper.

            Format your response as:
            💻 **Algorithm Overview**: [What does the code/algorithm do in one sentence]

            🔧 **Key Steps**:
            1. [Step 1]
            2. [Step 2]
            3. [Step 3]

            ⚡ **Complexity**: [Time/space complexity if mentioned, or "Not specified"]

            🛠️ **Implementation**: [Any frameworks, languages, or tools mentioned]

            If there's no code or algorithm, say "This paper doesn't introduce specific algorithms or code implementations."
            """

        case .methodology:
            styleInstructions = """
            Explain HOW they did it in 3-4 bullet points:
            • What data/tools did they use?
            • What's their approach?
            • How did they validate it?

            Keep each point under 20 words.
            """

        case .implications:
            styleInstructions = """
            Answer in 2-3 sentences:
            Why should I care? What could this enable in the real world?

            Be specific about applications. No generic "this advances the field" statements.
            """

        case .simpleExplanation:
            styleInstructions = """
            Explain this paper like I'm a curious 10-year-old.

            Use a fun analogy. No jargon. 3-4 sentences max.

            Start with something like "Imagine if..." or "You know how..."
            """
        }

        return baseContext + styleInstructions
    }

    static func systemPrompt() -> String {
        """
        You are a research paper explainer. Your job is to make complex papers accessible and interesting.

        Rules:
        - Be accurate but engaging
        - Use emojis sparingly for visual breaks
        - Never invent details not in the abstract
        - Match the requested format exactly
        - If something isn't in the abstract, say so
        - Keep responses concise - people are scrolling
        """
    }
}

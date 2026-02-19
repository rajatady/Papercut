//
//  SummaryStyle.swift
//  Papercut
//

import Foundation
import SwiftUI

enum SummaryStyle: String, Codable, CaseIterable, Identifiable {
    case tldr = "tldr"
    case keyFindings = "keyFindings"
    case mathExplained = "mathExplained"
    case codeExplained = "codeExplained"
    case methodology = "methodology"
    case implications = "implications"
    case simpleExplanation = "simpleExplanation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tldr:
            return "TL;DR"
        case .keyFindings:
            return "Key Points"
        case .mathExplained:
            return "The Math"
        case .codeExplained:
            return "The Code"
        case .methodology:
            return "How"
        case .implications:
            return "Why It Matters"
        case .simpleExplanation:
            return "ELI5"
        }
    }

    var description: String {
        switch self {
        case .tldr:
            return "Quick 2-sentence summary"
        case .keyFindings:
            return "Main takeaways"
        case .mathExplained:
            return "Math made simple"
        case .codeExplained:
            return "Code & algorithms"
        case .methodology:
            return "The approach"
        case .implications:
            return "Real-world impact"
        case .simpleExplanation:
            return "Anyone can understand"
        }
    }

    var iconName: String {
        switch self {
        case .tldr:
            return "bolt.fill"
        case .keyFindings:
            return "star.fill"
        case .mathExplained:
            return "function"
        case .codeExplained:
            return "chevron.left.forwardslash.chevron.right"
        case .methodology:
            return "gearshape.fill"
        case .implications:
            return "lightbulb.fill"
        case .simpleExplanation:
            return "face.smiling.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .tldr:
            return Color(hex: "5B8FB9")
        case .keyFindings:
            return Color(hex: "E4A853")
        case .mathExplained:
            return Color(hex: "9B7FBF")
        case .codeExplained:
            return Color(hex: "6DAE6D")
        case .methodology:
            return Color(hex: "5BBCCC")
        case .implications:
            return Color(hex: "E4BCB2")
        case .simpleExplanation:
            return Color(hex: "E4C95B")
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Quick access styles shown by default on cards
    static var quickAccessStyles: [SummaryStyle] {
        [.tldr, .keyFindings, .mathExplained, .codeExplained]
    }

    // Default styles to show for new users
    static var defaultEnabled: Set<SummaryStyle> {
        Set(SummaryStyle.allCases)
    }

    // The auto-summary style
    static var autoSummaryStyle: SummaryStyle {
        .tldr
    }
}

//
//  SummaryStyleTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct SummaryStyleTests {

    // MARK: - All Cases

    @Test func allCases_containsSevenStyles() {
        #expect(SummaryStyle.allCases.count == 7)
    }

    // MARK: - Raw Values

    @Test func rawValues_areCorrect() {
        #expect(SummaryStyle.tldr.rawValue == "tldr")
        #expect(SummaryStyle.keyFindings.rawValue == "keyFindings")
        #expect(SummaryStyle.mathExplained.rawValue == "mathExplained")
        #expect(SummaryStyle.codeExplained.rawValue == "codeExplained")
        #expect(SummaryStyle.methodology.rawValue == "methodology")
        #expect(SummaryStyle.implications.rawValue == "implications")
        #expect(SummaryStyle.simpleExplanation.rawValue == "simpleExplanation")
    }

    // MARK: - Identifiable

    @Test func id_matchesRawValue() {
        for style in SummaryStyle.allCases {
            #expect(style.id == style.rawValue)
        }
    }

    // MARK: - Display Properties

    @Test func displayName_nonEmpty() {
        for style in SummaryStyle.allCases {
            #expect(!style.displayName.isEmpty)
        }
    }

    @Test func displayName_specificValues() {
        #expect(SummaryStyle.tldr.displayName == "TL;DR")
        #expect(SummaryStyle.keyFindings.displayName == "Key Points")
        #expect(SummaryStyle.simpleExplanation.displayName == "ELI5")
    }

    @Test func description_nonEmpty() {
        for style in SummaryStyle.allCases {
            #expect(!style.description.isEmpty)
        }
    }

    @Test func iconName_nonEmpty() {
        for style in SummaryStyle.allCases {
            #expect(!style.iconName.isEmpty)
        }
    }

    @Test func iconName_specificValues() {
        #expect(SummaryStyle.tldr.iconName == "bolt.fill")
        #expect(SummaryStyle.keyFindings.iconName == "star.fill")
        #expect(SummaryStyle.mathExplained.iconName == "function")
    }

    // MARK: - Quick Access Styles

    @Test func quickAccessStyles_containsFourStyles() {
        #expect(SummaryStyle.quickAccessStyles.count == 4)
        #expect(SummaryStyle.quickAccessStyles.contains(.tldr))
        #expect(SummaryStyle.quickAccessStyles.contains(.keyFindings))
        #expect(SummaryStyle.quickAccessStyles.contains(.mathExplained))
        #expect(SummaryStyle.quickAccessStyles.contains(.codeExplained))
    }

    // MARK: - Default Enabled

    @Test func defaultEnabled_containsAllStyles() {
        #expect(SummaryStyle.defaultEnabled.count == SummaryStyle.allCases.count)
        for style in SummaryStyle.allCases {
            #expect(SummaryStyle.defaultEnabled.contains(style))
        }
    }

    // MARK: - Auto Summary Style

    @Test func autoSummaryStyle_isTldr() {
        #expect(SummaryStyle.autoSummaryStyle == .tldr)
    }

    // MARK: - Codable

    @Test func codable_roundTrip() throws {
        for style in SummaryStyle.allCases {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(SummaryStyle.self, from: data)
            #expect(decoded == style)
        }
    }

    @Test func codable_decodesFromRawString() throws {
        let json = "\"tldr\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SummaryStyle.self, from: json)
        #expect(decoded == .tldr)
    }
}

//
//  SummaryTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct SummaryTests {

    // MARK: - Default Init

    @Test func defaultInit_createsEmptySummary() {
        let summary = Summary()
        #expect(!summary.id.isEmpty)
        #expect(summary.paperId.isEmpty)
        #expect(summary.style == SummaryStyle.tldr.rawValue)
        #expect(summary.content.isEmpty)
        #expect(summary.isComplete == false)
    }

    // MARK: - Full Init

    @Test func fullInit_setsAllProperties() {
        let summary = Summary(paperId: "paper123", style: .keyFindings, content: "Key points here", isComplete: true)

        #expect(summary.paperId == "paper123")
        #expect(summary.style == "keyFindings")
        #expect(summary.content == "Key points here")
        #expect(summary.isComplete == true)
    }

    @Test func fullInit_generatesCorrectId() {
        let summary = Summary(paperId: "paper123", style: .mathExplained)
        #expect(summary.id == "paper123_mathExplained")
    }

    @Test func fullInit_defaultsToIncomplete() {
        let summary = Summary(paperId: "paper123", style: .tldr, content: "test")
        #expect(summary.isComplete == false)
    }

    // MARK: - summaryStyle Computed Property

    @Test func summaryStyle_returnCorrectStyle() {
        let summary = Summary(paperId: "p1", style: .codeExplained)
        #expect(summary.summaryStyle == .codeExplained)
    }

    @Test func summaryStyle_returnsNilForInvalidStyle() {
        let summary = Summary()
        summary.style = "invalidStyle"
        #expect(summary.summaryStyle == nil)
    }

    // MARK: - makeId

    @Test func makeId_generatesCorrectFormat() {
        let id = Summary.makeId(paperId: "2401.12345", style: .tldr)
        #expect(id == "2401.12345_tldr")
    }

    @Test func makeId_allStyles() {
        for style in SummaryStyle.allCases {
            let id = Summary.makeId(paperId: "paper", style: style)
            #expect(id == "paper_\(style.rawValue)")
        }
    }

    @Test func makeId_matchesInitId() {
        let summary = Summary(paperId: "myPaper", style: .implications)
        let staticId = Summary.makeId(paperId: "myPaper", style: .implications)
        #expect(summary.id == staticId)
    }
}

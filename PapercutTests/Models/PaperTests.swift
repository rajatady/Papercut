//
//  PaperTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct PaperTests {

    // MARK: - Helpers

    private func makePaper(
        id: String = "2401.12345",
        title: String = "Test Paper",
        abstract: String = "This is a test abstract",
        authors: [Author] = [Author(name: "Jane Doe")],
        categories: [String] = ["cs.AI"],
        publishedDate: Date = Date(),
        updatedDate: Date = Date(),
        pdfURL: String = "https://arxiv.org/pdf/2401.12345v1",
        abstractURL: String = "https://arxiv.org/abs/2401.12345"
    ) -> Paper {
        Paper(
            id: id,
            title: title,
            abstract: abstract,
            authors: authors,
            categories: categories,
            publishedDate: publishedDate,
            updatedDate: updatedDate,
            pdfURL: pdfURL,
            abstractURL: abstractURL
        )
    }

    // MARK: - Init

    @Test func defaultInit_createsEmptyPaper() {
        let paper = Paper()
        #expect(!paper.id.isEmpty)
        #expect(paper.title.isEmpty)
        #expect(paper.abstract.isEmpty)
        #expect(paper.authors.isEmpty)
        #expect(paper.categories.isEmpty)
    }

    @Test func fullInit_setsAllProperties() {
        let date = Date()
        let paper = makePaper(publishedDate: date, updatedDate: date)

        #expect(paper.id == "2401.12345")
        #expect(paper.title == "Test Paper")
        #expect(paper.abstract == "This is a test abstract")
        #expect(paper.authors.count == 1)
        #expect(paper.authors.first?.name == "Jane Doe")
        #expect(paper.categories == ["cs.AI"])
        #expect(paper.pdfURL == "https://arxiv.org/pdf/2401.12345v1")
        #expect(paper.abstractURL == "https://arxiv.org/abs/2401.12345")
    }

    // MARK: - Authors Encoding/Decoding

    @Test func authors_encodesAndDecodesRoundTrip() {
        let authors = [
            Author(name: "Alice Smith", affiliation: "MIT"),
            Author(name: "Bob Jones")
        ]
        let paper = makePaper(authors: authors)

        #expect(paper.authors.count == 2)
        #expect(paper.authors[0].name == "Alice Smith")
        #expect(paper.authors[0].affiliation == "MIT")
        #expect(paper.authors[1].name == "Bob Jones")
        #expect(paper.authors[1].affiliation == nil)
    }

    @Test func authors_setterUpdatesData() {
        let paper = makePaper()
        paper.authors = [Author(name: "New Author")]

        #expect(paper.authors.count == 1)
        #expect(paper.authors[0].name == "New Author")
    }

    // MARK: - Categories Encoding/Decoding

    @Test func categories_encodesAndDecodesRoundTrip() {
        let paper = makePaper(categories: ["cs.AI", "cs.LG", "stat.ML"])

        #expect(paper.categories.count == 3)
        #expect(paper.categories.contains("cs.AI"))
        #expect(paper.categories.contains("stat.ML"))
    }

    @Test func categories_setterUpdatesData() {
        let paper = makePaper()
        paper.categories = ["physics.comp-ph"]

        #expect(paper.categories == ["physics.comp-ph"])
    }

    // MARK: - Computed Properties

    @Test func primaryCategory_returnsFirstCategory() {
        let paper = makePaper(categories: ["cs.CV", "cs.AI"])
        #expect(paper.primaryCategory == "cs.CV")
    }

    @Test func primaryCategory_returnsNilWhenEmpty() {
        let paper = makePaper(categories: [])
        #expect(paper.primaryCategory == nil)
    }

    @Test func formattedDate_returnsAbbreviatedDate() {
        let paper = makePaper()
        let formatted = paper.formattedDate
        #expect(!formatted.isEmpty)
    }

    @Test func isRecent_trueForTodaysPaper() {
        let paper = makePaper(publishedDate: Date())
        #expect(paper.isRecent == true)
    }

    @Test func isRecent_falseForOldPaper() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let paper = makePaper(publishedDate: oldDate)
        #expect(paper.isRecent == false)
    }

    @Test func isRecent_trueForOneDayOldPaper() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let paper = makePaper(publishedDate: yesterday)
        #expect(paper.isRecent == true)
    }

    // MARK: - Summary Helpers

    @Test func summary_returnsNilWhenNoSummaries() {
        let paper = makePaper()
        #expect(paper.summary(for: .tldr) == nil)
    }

    @Test func hasSummary_falseWhenNoSummaries() {
        let paper = makePaper()
        #expect(paper.hasSummary(for: .tldr) == false)
    }

    @Test func addSummary_appendsNewSummary() {
        let paper = makePaper()
        let summary = Summary(paperId: paper.id, style: .tldr, content: "Short summary", isComplete: true)
        paper.addSummary(summary)

        #expect(paper.summaries.count == 1)
        #expect(paper.summary(for: .tldr)?.content == "Short summary")
        #expect(paper.hasSummary(for: .tldr) == true)
    }

    @Test func addSummary_replacesExistingSameStyle() {
        let paper = makePaper()
        let first = Summary(paperId: paper.id, style: .tldr, content: "First", isComplete: true)
        paper.addSummary(first)

        let second = Summary(paperId: paper.id, style: .tldr, content: "Updated", isComplete: true)
        paper.addSummary(second)

        #expect(paper.summaries.count == 1)
        #expect(paper.summary(for: .tldr)?.content == "Updated")
    }

    @Test func addSummary_keepsDifferentStyles() {
        let paper = makePaper()
        paper.addSummary(Summary(paperId: paper.id, style: .tldr, content: "TLDR", isComplete: true))
        paper.addSummary(Summary(paperId: paper.id, style: .keyFindings, content: "Key points", isComplete: true))

        #expect(paper.summaries.count == 2)
        #expect(paper.hasSummary(for: .tldr) == true)
        #expect(paper.hasSummary(for: .keyFindings) == true)
        #expect(paper.hasSummary(for: .mathExplained) == false)
    }

    // MARK: - URL Helpers

    @Test func pdfURLObject_returnsValidURL() {
        let paper = makePaper(pdfURL: "https://arxiv.org/pdf/2401.12345v1")
        #expect(paper.pdfURLObject != nil)
        #expect(paper.pdfURLObject?.absoluteString == "https://arxiv.org/pdf/2401.12345v1")
    }

    @Test func pdfURLObject_returnsNilForInvalidURL() {
        let paper = makePaper(pdfURL: "")
        #expect(paper.pdfURLObject == nil)
    }

    @Test func abstractURLObject_returnsValidURL() {
        let paper = makePaper(abstractURL: "https://arxiv.org/abs/2401.12345")
        #expect(paper.abstractURLObject != nil)
    }

    @Test func arXivId_extractsNumericId() {
        let paper = makePaper(id: "http://arxiv.org/abs/2401.12345v1")
        #expect(paper.arXivId == "2401.12345v1")
    }

    @Test func arXivId_returnsIdWhenAlreadyNumeric() {
        let paper = makePaper(id: "2401.12345")
        #expect(paper.arXivId == "2401.12345")
    }

    @Test func arXivId_returnsFullIdWhenNoMatch() {
        let paper = makePaper(id: "some-other-format")
        #expect(paper.arXivId == "some-other-format")
    }

    // MARK: - Stale Check

    @Test func isStale_falseForFreshPaper() {
        let paper = makePaper()
        #expect(paper.isStale == false)
    }

    @Test func isStale_trueForOldFetchedPaper() {
        let paper = makePaper()
        paper.fetchedAt = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        #expect(paper.isStale == true)
    }

    @Test func markAsRefreshed_updatesFetchedAt() {
        let paper = makePaper()
        paper.fetchedAt = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        #expect(paper.isStale == true)

        paper.markAsRefreshed()
        #expect(paper.isStale == false)
    }
}

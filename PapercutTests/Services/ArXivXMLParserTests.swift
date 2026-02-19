//
//  ArXivXMLParserTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct ArXivXMLParserTests {

    // MARK: - Helpers

    private func makeXML(entries: String, totalResults: Int = 1) -> Data {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"
              xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/"
              xmlns:arxiv="http://arxiv.org/schemas/atom">
          <title>ArXiv Query</title>
          <opensearch:totalResults>\(totalResults)</opensearch:totalResults>
          \(entries)
        </feed>
        """.data(using: .utf8)!
    }

    private var sampleEntry: String {
        """
        <entry>
          <id>http://arxiv.org/abs/2401.12345v1</id>
          <title>A Test Paper on Transformers</title>
          <summary>This paper presents a novel approach to transformer architecture.</summary>
          <published>2024-01-15T18:00:00Z</published>
          <updated>2024-01-16T10:00:00Z</updated>
          <author>
            <name>Alice Smith</name>
            <arxiv:affiliation>MIT</arxiv:affiliation>
          </author>
          <author>
            <name>Bob Jones</name>
          </author>
          <link href="http://arxiv.org/abs/2401.12345v1" rel="alternate" type="text/html"/>
          <link href="http://arxiv.org/pdf/2401.12345v1" title="pdf" type="application/pdf"/>
          <category term="cs.AI" scheme="http://arxiv.org/schemas/atom"/>
          <category term="cs.LG" scheme="http://arxiv.org/schemas/atom"/>
        </entry>
        """
    }

    // MARK: - Basic Parsing

    @Test func parse_singleEntry() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry, totalResults: 1)
        let result = try parser.parse(data: data)

        #expect(result.papers.count == 1)
        #expect(result.totalResults == 1)
    }

    @Test func parse_paperFields() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry)
        let result = try parser.parse(data: data)
        let paper = result.papers[0]

        #expect(paper.id == "http://arxiv.org/abs/2401.12345v1")
        #expect(paper.title == "A Test Paper on Transformers")
        #expect(paper.abstract.contains("novel approach"))
        #expect(paper.pdfURL == "http://arxiv.org/pdf/2401.12345v1")
    }

    @Test func parse_authors() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry)
        let result = try parser.parse(data: data)
        let paper = result.papers[0]

        #expect(paper.authors.count == 2)
        #expect(paper.authors[0].name == "Alice Smith")
        #expect(paper.authors[1].name == "Bob Jones")
    }

    @Test func parse_categories() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry)
        let result = try parser.parse(data: data)
        let paper = result.papers[0]

        #expect(paper.categories.count == 2)
        #expect(paper.categories.contains("cs.AI"))
        #expect(paper.categories.contains("cs.LG"))
    }

    @Test func parse_dates() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry)
        let result = try parser.parse(data: data)
        let paper = result.papers[0]

        #expect(paper.published != nil)
        #expect(paper.updated != nil)
    }

    // MARK: - Multiple Entries

    @Test func parse_multipleEntries() throws {
        let secondEntry = """
        <entry>
          <id>http://arxiv.org/abs/2401.99999v1</id>
          <title>Second Paper</title>
          <summary>Another paper.</summary>
          <published>2024-01-20T12:00:00Z</published>
          <updated>2024-01-20T12:00:00Z</updated>
          <author><name>Charlie</name></author>
          <category term="stat.ML"/>
        </entry>
        """
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry + secondEntry, totalResults: 100)
        let result = try parser.parse(data: data)

        #expect(result.papers.count == 2)
        #expect(result.totalResults == 100)
        #expect(result.papers[0].title == "A Test Paper on Transformers")
        #expect(result.papers[1].title == "Second Paper")
    }

    // MARK: - Empty Feed

    @Test func parse_emptyFeed() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: "", totalResults: 0)
        let result = try parser.parse(data: data)

        #expect(result.papers.isEmpty)
        #expect(result.totalResults == 0)
    }

    // MARK: - Title Cleanup

    @Test func parse_cleansUpMultilineTitle() throws {
        let entry = """
        <entry>
          <id>http://arxiv.org/abs/2401.00001v1</id>
          <title>A Very Long Title
          That Spans Multiple Lines
          With  Extra  Spaces</title>
          <summary>Abstract</summary>
          <published>2024-01-01T00:00:00Z</published>
          <updated>2024-01-01T00:00:00Z</updated>
          <author><name>Test</name></author>
          <category term="cs.AI"/>
        </entry>
        """
        let parser = ArXivXMLParser()
        let data = makeXML(entries: entry)
        let result = try parser.parse(data: data)

        let title = result.papers[0].title
        #expect(!title.contains("\n"))
    }

    // MARK: - toPaper Conversion

    @Test func toPaper_convertsCorrectly() throws {
        let parser = ArXivXMLParser()
        let data = makeXML(entries: sampleEntry)
        let result = try parser.parse(data: data)
        let paper = result.papers[0].toPaper()

        #expect(paper.id == "http://arxiv.org/abs/2401.12345v1")
        #expect(paper.title == "A Test Paper on Transformers")
        #expect(paper.authors.count == 2)
        #expect(paper.categories.count == 2)
        #expect(paper.pdfURL == "http://arxiv.org/pdf/2401.12345v1")
    }

    // MARK: - Error Handling

    @Test func parse_invalidXML_throws() {
        let parser = ArXivXMLParser()
        let badData = "not xml at all".data(using: .utf8)!

        #expect(throws: ArXivParserError.self) {
            _ = try parser.parse(data: badData)
        }
    }

    // MARK: - Abstract URL Fallback

    @Test func parse_abstractURLFallsBackToId() throws {
        let entry = """
        <entry>
          <id>http://arxiv.org/abs/2401.55555v1</id>
          <title>No Links Paper</title>
          <summary>Abstract</summary>
          <published>2024-01-01T00:00:00Z</published>
          <updated>2024-01-01T00:00:00Z</updated>
          <author><name>Test</name></author>
          <category term="cs.AI"/>
        </entry>
        """
        let parser = ArXivXMLParser()
        let data = makeXML(entries: entry)
        let result = try parser.parse(data: data)

        // When no explicit abstract link, the id URL is used
        #expect(result.papers[0].abstractURL == "http://arxiv.org/abs/2401.55555v1")
    }
}

// MARK: - ArXivParserError Tests

@Suite(.serialized)
struct ArXivParserErrorTests {

    @Test func parsingFailed_withUnderlyingError_hasDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad xml"])
        let error = ArXivParserError.parsingFailed(underlying)
        #expect(error.errorDescription?.contains("bad xml") == true)
    }

    @Test func parsingFailed_withoutUnderlyingError_hasDescription() {
        let error = ArXivParserError.parsingFailed(nil)
        #expect(error.errorDescription?.contains("Failed to parse") == true)
    }
}

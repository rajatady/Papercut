//
//  ArXivServiceTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct ArXivServiceTests {

    // MARK: - Helpers

    private func makeService() -> ArXivService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return ArXivService(session: session)
    }

    private func makeSampleXML(count: Int = 1, totalResults: Int = 1) -> Data {
        var entries = ""
        for i in 0..<count {
            entries += """
            <entry>
              <id>http://arxiv.org/abs/2401.\(String(format: "%05d", i))v1</id>
              <title>Paper \(i)</title>
              <summary>Abstract \(i)</summary>
              <published>2024-01-15T18:00:00Z</published>
              <updated>2024-01-15T18:00:00Z</updated>
              <author><name>Author \(i)</name></author>
              <link href="http://arxiv.org/pdf/2401.\(String(format: "%05d", i))v1" title="pdf"/>
              <category term="cs.AI"/>
            </entry>
            """
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"
              xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
          <opensearch:totalResults>\(totalResults)</opensearch:totalResults>
          \(entries)
        </feed>
        """.data(using: .utf8)!
    }

    private func setupMock(data: Data, statusCode: Int = 200) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
    }

    // MARK: - fetchPapers

    @Test func fetchPapers_emptyCategories_returnsEmpty() async throws {
        let service = makeService()
        let response = try await service.fetchPapers(categories: [], page: 0, pageSize: 10, sortBy: .submittedDate)

        #expect(response.papers.isEmpty)
        #expect(response.totalResults == 0)
        #expect(response.hasMore == false)
    }

    @Test func fetchPapers_validResponse_returnsPapers() async throws {
        let service = makeService()
        setupMock(data: makeSampleXML(count: 3, totalResults: 100))

        let response = try await service.fetchPapers(categories: ["cs.AI"], page: 0, pageSize: 10, sortBy: .submittedDate)

        #expect(response.papers.count == 3)
        #expect(response.totalResults == 100)
        #expect(response.hasMore == true)
    }

    @Test func fetchPapers_httpError_throws() async {
        let service = makeService()
        setupMock(data: Data(), statusCode: 403)

        do {
            _ = try await service.fetchPapers(categories: ["cs.AI"], page: 0, pageSize: 10, sortBy: .submittedDate)
            Issue.record("Expected to throw")
        } catch let error as ArXivServiceError {
            if case .httpError(let code) = error {
                #expect(code == 403)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - searchPapers

    @Test func searchPapers_emptyQuery_returnsEmpty() async throws {
        let service = makeService()
        let response = try await service.searchPapers(query: "  ", page: 0, pageSize: 10)

        #expect(response.papers.isEmpty)
        #expect(response.totalResults == 0)
    }

    @Test func searchPapers_validQuery_returnsPapers() async throws {
        let service = makeService()
        setupMock(data: makeSampleXML(count: 2, totalResults: 50))

        let response = try await service.searchPapers(query: "transformer", page: 0, pageSize: 10)

        #expect(response.papers.count == 2)
        #expect(response.totalResults == 50)
    }

    // MARK: - fetchTrending

    @Test func fetchTrending_emptyCategories_returnsEmpty() async throws {
        let service = makeService()
        let response = try await service.fetchTrending(categories: [], limit: 50)

        #expect(response.papers.isEmpty)
    }

    @Test func fetchTrending_validResponse_returnsPapers() async throws {
        let service = makeService()
        setupMock(data: makeSampleXML(count: 5, totalResults: 5))

        let response = try await service.fetchTrending(categories: ["cs.AI"], limit: 50)

        #expect(response.papers.count == 5)
    }

    // MARK: - fetchPaper

    @Test func fetchPaper_validId_returnsPaper() async throws {
        let service = makeService()
        setupMock(data: makeSampleXML(count: 1, totalResults: 1))

        let paper = try await service.fetchPaper(id: "2401.12345")
        #expect(paper != nil)
    }

    @Test func fetchPaper_notFound_returnsNil() async throws {
        let service = makeService()
        setupMock(data: makeSampleXML(count: 0, totalResults: 0))

        let paper = try await service.fetchPaper(id: "9999.99999")
        #expect(paper == nil)
    }

    // MARK: - hasMore Calculation

    @Test func hasMore_trueWhenMoreResultsExist() async throws {
        let service = makeService()
        // 3 papers returned, total is 100, start at 0 with pageSize 10
        // (0 + 3) < 100 → hasMore = true
        setupMock(data: makeSampleXML(count: 3, totalResults: 100))

        let response = try await service.fetchPapers(categories: ["cs.AI"], page: 0, pageSize: 10, sortBy: .submittedDate)
        #expect(response.hasMore == true)
    }

    @Test func hasMore_falseWhenAllResultsReturned() async throws {
        let service = makeService()
        // 3 papers returned, total is 3, start at 0
        // (0 + 3) < 3 → false → hasMore = false
        setupMock(data: makeSampleXML(count: 3, totalResults: 3))

        let response = try await service.fetchPapers(categories: ["cs.AI"], page: 0, pageSize: 10, sortBy: .submittedDate)
        #expect(response.hasMore == false)
    }
}

// MARK: - ArXivServiceError Tests

@Suite(.serialized)
struct ArXivServiceErrorTests {

    @Test func invalidURL_hasDescription() {
        let error = ArXivServiceError.invalidURL
        #expect(error.errorDescription?.contains("Invalid") == true)
    }

    @Test func invalidResponse_hasDescription() {
        let error = ArXivServiceError.invalidResponse
        #expect(error.errorDescription?.contains("Invalid response") == true)
    }

    @Test func httpError_includesStatusCode() {
        let error = ArXivServiceError.httpError(statusCode: 404)
        #expect(error.errorDescription?.contains("404") == true)
    }

    @Test func noData_hasDescription() {
        let error = ArXivServiceError.noData
        #expect(error.errorDescription?.contains("No data") == true)
    }
}

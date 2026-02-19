//
//  ArXivEndpointTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct ArXivEndpointTests {

    // MARK: - Constants

    @Test func defaultPageSize_is20() {
        #expect(ArXivEndpoint.defaultPageSize == 20)
    }

    @Test func maxPageSize_is100() {
        #expect(ArXivEndpoint.maxPageSize == 100)
    }

    @Test func rateLimitDelay_is3Seconds() {
        #expect(ArXivEndpoint.rateLimitDelay == 3.0)
    }

    // MARK: - Search URL

    @Test func searchURL_validForSingleCategory() {
        let endpoint = ArXivEndpoint.search(categories: ["cs.AI"], maxResults: 10, start: 0, sortBy: .submittedDate)
        let url = endpoint.url

        #expect(url != nil)
        let urlString = url!.absoluteString
        #expect(urlString.contains("export.arxiv.org"))
        #expect(urlString.contains("api/query"))
        #expect(urlString.contains("cat:cs.AI"))
        #expect(urlString.contains("max_results=10"))
        #expect(urlString.contains("start=0"))
        #expect(urlString.contains("sortBy=submittedDate"))
        #expect(urlString.contains("sortOrder=descending"))
    }

    @Test func searchURL_multipleCategories_joinedWithOR() {
        let endpoint = ArXivEndpoint.search(categories: ["cs.AI", "cs.LG"], maxResults: 20, start: 0, sortBy: .submittedDate)
        let url = endpoint.url

        #expect(url != nil)
        // URL encoding will change spaces/OR but the query should contain both categories
        let urlString = url!.absoluteString
        #expect(urlString.contains("cs.AI"))
        #expect(urlString.contains("cs.LG"))
    }

    @Test func searchURL_pagination() {
        let endpoint = ArXivEndpoint.search(categories: ["cs.AI"], maxResults: 10, start: 20, sortBy: .submittedDate)
        let url = endpoint.url

        #expect(url != nil)
        #expect(url!.absoluteString.contains("start=20"))
    }

    @Test func searchURL_differentSortOrders() {
        let byDate = ArXivEndpoint.search(categories: ["cs.AI"], maxResults: 10, start: 0, sortBy: .submittedDate)
        let byRelevance = ArXivEndpoint.search(categories: ["cs.AI"], maxResults: 10, start: 0, sortBy: .relevance)
        let byUpdated = ArXivEndpoint.search(categories: ["cs.AI"], maxResults: 10, start: 0, sortBy: .lastUpdatedDate)

        #expect(byDate.url!.absoluteString.contains("sortBy=submittedDate"))
        #expect(byRelevance.url!.absoluteString.contains("sortBy=relevance"))
        #expect(byUpdated.url!.absoluteString.contains("sortBy=lastUpdatedDate"))
    }

    // MARK: - Query URL

    @Test func queryURL_validForSearchTerm() {
        let endpoint = ArXivEndpoint.query(searchTerm: "transformer", maxResults: 10, start: 0, sortBy: .relevance)
        let url = endpoint.url

        #expect(url != nil)
        let urlString = url!.absoluteString
        #expect(urlString.contains("export.arxiv.org"))
        #expect(urlString.contains("transformer"))
        #expect(urlString.contains("sortBy=relevance"))
    }

    @Test func queryURL_pagination() {
        let endpoint = ArXivEndpoint.query(searchTerm: "test", maxResults: 20, start: 40, sortBy: .relevance)
        let url = endpoint.url

        #expect(url != nil)
        #expect(url!.absoluteString.contains("start=40"))
        #expect(url!.absoluteString.contains("max_results=20"))
    }

    // MARK: - Paper URL

    @Test func paperURL_validForId() {
        let endpoint = ArXivEndpoint.paper(id: "2401.12345")
        let url = endpoint.url

        #expect(url != nil)
        let urlString = url!.absoluteString
        #expect(urlString.contains("export.arxiv.org"))
        #expect(urlString.contains("id_list=2401.12345"))
    }

    // MARK: - Trending URL

    @Test func trendingURL_validForCategories() {
        let endpoint = ArXivEndpoint.trending(categories: ["cs.AI", "cs.LG"], maxResults: 50)
        let url = endpoint.url

        #expect(url != nil)
        let urlString = url!.absoluteString
        #expect(urlString.contains("cs.AI"))
        #expect(urlString.contains("cs.LG"))
        #expect(urlString.contains("max_results=50"))
        #expect(urlString.contains("sortBy=relevance"))
        #expect(urlString.contains("start=0"))
    }

    // MARK: - URL Scheme

    @Test func allEndpoints_useHTTPS() {
        let endpoints: [ArXivEndpoint] = [
            .search(categories: ["cs.AI"], maxResults: 10, start: 0, sortBy: .submittedDate),
            .query(searchTerm: "test", maxResults: 10, start: 0, sortBy: .relevance),
            .paper(id: "2401.12345"),
            .trending(categories: ["cs.AI"], maxResults: 50)
        ]

        for endpoint in endpoints {
            let url = endpoint.url
            #expect(url?.scheme == "https")
        }
    }

    @Test func allEndpoints_useExportHost() {
        let endpoints: [ArXivEndpoint] = [
            .search(categories: ["cs.AI"], maxResults: 10, start: 0, sortBy: .submittedDate),
            .query(searchTerm: "test", maxResults: 10, start: 0, sortBy: .relevance),
            .paper(id: "2401.12345"),
            .trending(categories: ["cs.AI"], maxResults: 50)
        ]

        for endpoint in endpoints {
            let url = endpoint.url
            #expect(url?.host == "export.arxiv.org")
        }
    }
}

// MARK: - ArXivSortBy Tests

@Suite(.serialized)
struct ArXivSortByTests {

    @Test func rawValues_correct() {
        #expect(ArXivSortBy.submittedDate.rawValue == "submittedDate")
        #expect(ArXivSortBy.lastUpdatedDate.rawValue == "lastUpdatedDate")
        #expect(ArXivSortBy.relevance.rawValue == "relevance")
    }
}

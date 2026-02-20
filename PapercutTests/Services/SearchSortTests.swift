//
//  SearchSortTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite struct SearchSortTests {

    // MARK: - ArXivEndpoint URL building with sortBy

    @Test func endpoint_query_sortByRelevance_producesCorrectURL() {
        let url = ArXivEndpoint.query(
            searchTerm: "continual learning",
            maxResults: 20,
            start: 0,
            sortBy: .relevance
        ).url

        let urlString = url?.absoluteString ?? ""
        #expect(urlString.contains("sortBy=relevance"))
        #expect(urlString.contains("all:%22continual%20learning%22") || urlString.contains("all:\"continual learning\"") || urlString.contains("all:%22continual+learning%22"))
    }

    @Test func endpoint_query_sortBySubmittedDate_producesCorrectURL() {
        let url = ArXivEndpoint.query(
            searchTerm: "transformers",
            maxResults: 20,
            start: 0,
            sortBy: .submittedDate
        ).url

        let urlString = url?.absoluteString ?? ""
        #expect(urlString.contains("sortBy=submittedDate"))
    }

    @Test func endpoint_query_sortByLastUpdated_producesCorrectURL() {
        let url = ArXivEndpoint.query(
            searchTerm: "diffusion models",
            maxResults: 20,
            start: 0,
            sortBy: .lastUpdatedDate
        ).url

        let urlString = url?.absoluteString ?? ""
        #expect(urlString.contains("sortBy=lastUpdatedDate"))
    }

    // MARK: - ArXivSortBy display properties

    @Test func arXivSortBy_hasDisplayName() {
        #expect(!ArXivSortBy.relevance.displayName.isEmpty)
        #expect(!ArXivSortBy.submittedDate.displayName.isEmpty)
        #expect(!ArXivSortBy.lastUpdatedDate.displayName.isEmpty)
    }

    @Test func arXivSortBy_hasIconName() {
        #expect(!ArXivSortBy.relevance.iconName.isEmpty)
        #expect(!ArXivSortBy.submittedDate.iconName.isEmpty)
        #expect(!ArXivSortBy.lastUpdatedDate.iconName.isEmpty)
    }

    @Test func arXivSortBy_allSearchCases() {
        let cases = ArXivSortBy.searchCases
        #expect(cases.count == 3)
        #expect(cases.contains(.relevance))
        #expect(cases.contains(.submittedDate))
        #expect(cases.contains(.lastUpdatedDate))
    }
}

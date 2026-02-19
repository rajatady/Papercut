//
//  ArXivEndpoint.swift
//  Papercut
//

import Foundation

enum ArXivSortBy: String {
    case submittedDate = "submittedDate"
    case lastUpdatedDate = "lastUpdatedDate"
    case relevance = "relevance"
}

enum ArXivSortOrder: String {
    case descending = "descending"
    case ascending = "ascending"
}

enum ArXivEndpoint {
    case search(categories: [String], maxResults: Int, start: Int, sortBy: ArXivSortBy)
    case query(searchTerm: String, maxResults: Int, start: Int, sortBy: ArXivSortBy)
    case paper(id: String)
    case trending(categories: [String], maxResults: Int)

    var url: URL? {
        switch self {
        case .search(let categories, let maxResults, let start, let sortBy):
            return buildSearchURL(categories: categories, maxResults: maxResults, start: start, sortBy: sortBy)
        case .query(let searchTerm, let maxResults, let start, let sortBy):
            return buildQueryURL(searchTerm: searchTerm, maxResults: maxResults, start: start, sortBy: sortBy)
        case .paper(let id):
            return buildPaperURL(id: id)
        case .trending(let categories, let maxResults):
            return buildTrendingURL(categories: categories, maxResults: maxResults)
        }
    }

    // MARK: - URL Builders

    private func buildSearchURL(categories: [String], maxResults: Int, start: Int, sortBy: ArXivSortBy) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "export.arxiv.org"
        components.path = "/api/query"

        // Build category query: cat:cs.AI OR cat:cs.LG
        let categoryQuery = categories
            .map { "cat:\($0)" }
            .joined(separator: " OR ")

        components.queryItems = [
            URLQueryItem(name: "search_query", value: categoryQuery),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "max_results", value: String(maxResults)),
            URLQueryItem(name: "sortBy", value: sortBy.rawValue),
            URLQueryItem(name: "sortOrder", value: ArXivSortOrder.descending.rawValue)
        ]

        return components.url
    }

    private func buildQueryURL(searchTerm: String, maxResults: Int, start: Int, sortBy: ArXivSortBy) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "export.arxiv.org"
        components.path = "/api/query"

        // Search in title and abstract
        let query = "all:\(searchTerm)"

        components.queryItems = [
            URLQueryItem(name: "search_query", value: query),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "max_results", value: String(maxResults)),
            URLQueryItem(name: "sortBy", value: sortBy.rawValue),
            URLQueryItem(name: "sortOrder", value: ArXivSortOrder.descending.rawValue)
        ]

        return components.url
    }

    private func buildPaperURL(id: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "export.arxiv.org"
        components.path = "/api/query"

        components.queryItems = [
            URLQueryItem(name: "id_list", value: id)
        ]

        return components.url
    }

    private func buildTrendingURL(categories: [String], maxResults: Int) -> URL? {
        // Trending: papers from the last 30 days in user's categories,
        // sorted by relevance (cross-listing frequency + category match).
        var components = URLComponents()
        components.scheme = "https"
        components.host = "export.arxiv.org"
        components.path = "/api/query"

        let categoryQuery = categories
            .map { "cat:\($0)" }
            .joined(separator: " OR ")

        // Date range: 30 days ago to now, format YYYYMMDDTTTT
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone(identifier: "GMT")
        let fromDate = fmt.string(from: thirtyDaysAgo) + "0000"
        let toDate = fmt.string(from: now) + "2359"

        let fullQuery = "(\(categoryQuery)) AND submittedDate:[\(fromDate) TO \(toDate)]"

        components.queryItems = [
            URLQueryItem(name: "search_query", value: fullQuery),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "max_results", value: String(maxResults)),
            URLQueryItem(name: "sortBy", value: ArXivSortBy.relevance.rawValue),
            URLQueryItem(name: "sortOrder", value: ArXivSortOrder.descending.rawValue)
        ]

        return components.url
    }
}

// MARK: - API Constants
extension ArXivEndpoint {
    static let defaultPageSize = 20
    static let maxPageSize = 100

    // Rate limiting: ArXiv recommends waiting 3 seconds between requests
    static let rateLimitDelay: TimeInterval = 3.0
}

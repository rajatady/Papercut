//
//  ArXivService.swift
//  Papercut
//

import Foundation

protocol ArXivServiceProtocol: Sendable {
    func fetchPapers(categories: [String], page: Int, pageSize: Int, sortBy: ArXivSortBy) async throws -> ArXivResponse
    func searchPapers(query: String, page: Int, pageSize: Int, sortBy: ArXivSortBy, sortOrder: ArXivSortOrder, categories: [String]) async throws -> ArXivResponse
    func fetchTrending(categories: [String], limit: Int) async throws -> ArXivResponse
    func fetchPaper(id: String) async throws -> Paper?
}

struct ArXivResponse: Sendable {
    let papers: [Paper]
    let totalResults: Int
    let hasMore: Bool
}

final class ArXivService: ArXivServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private var lastRequestTime: Date?
    private let lock = NSLock()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public Methods

    func fetchPapers(
        categories: [String],
        page: Int = 0,
        pageSize: Int = ArXivEndpoint.defaultPageSize,
        sortBy: ArXivSortBy = .submittedDate
    ) async throws -> ArXivResponse {
        guard !categories.isEmpty else {
            return ArXivResponse(papers: [], totalResults: 0, hasMore: false)
        }

        await respectRateLimit()

        let start = page * pageSize
        guard let url = ArXivEndpoint.search(
            categories: categories,
            maxResults: pageSize,
            start: start,
            sortBy: sortBy
        ).url else {
            throw ArXivServiceError.invalidURL
        }

        return try await fetchAndParse(url: url, start: start, pageSize: pageSize)
    }

    func searchPapers(
        query: String,
        page: Int = 0,
        pageSize: Int = ArXivEndpoint.defaultPageSize,
        sortBy: ArXivSortBy = .relevance,
        sortOrder: ArXivSortOrder = .descending,
        categories: [String] = []
    ) async throws -> ArXivResponse {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ArXivResponse(papers: [], totalResults: 0, hasMore: false)
        }

        await respectRateLimit()

        let start = page * pageSize
        guard let url = ArXivEndpoint.query(
            searchTerm: query,
            maxResults: pageSize,
            start: start,
            sortBy: sortBy,
            sortOrder: sortOrder,
            categories: categories
        ).url else {
            throw ArXivServiceError.invalidURL
        }

        return try await fetchAndParse(url: url, start: start, pageSize: pageSize)
    }

    func fetchTrending(
        categories: [String],
        limit: Int = 50
    ) async throws -> ArXivResponse {
        guard !categories.isEmpty else {
            return ArXivResponse(papers: [], totalResults: 0, hasMore: false)
        }

        await respectRateLimit()

        guard let url = ArXivEndpoint.trending(
            categories: categories,
            maxResults: limit
        ).url else {
            throw ArXivServiceError.invalidURL
        }

        return try await fetchAndParse(url: url, start: 0, pageSize: limit)
    }

    func fetchPaper(id: String) async throws -> Paper? {
        await respectRateLimit()

        guard let url = ArXivEndpoint.paper(id: id).url else {
            throw ArXivServiceError.invalidURL
        }

        let response = try await fetchAndParse(url: url, start: 0, pageSize: 1)
        return response.papers.first
    }

    // MARK: - Private Methods

    private func fetchAndParse(url: URL, start: Int, pageSize: Int) async throws -> ArXivResponse {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArXivServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ArXivServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw ArXivServiceError.noData
        }

        updateLastRequestTime()

        let parser = ArXivXMLParser()
        let result = try parser.parse(data: data)
        let papers = result.papers.map { $0.toPaper() }

        let hasMore = (start + papers.count) < result.totalResults

        return ArXivResponse(
            papers: papers,
            totalResults: result.totalResults,
            hasMore: hasMore
        )
    }

    // MARK: - Rate Limiting

    private func respectRateLimit() async {
        lock.lock()
        let lastRequest = lastRequestTime
        lock.unlock()

        guard let lastRequest else { return }

        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        let delay = ArXivEndpoint.rateLimitDelay - timeSinceLastRequest

        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    private func updateLastRequestTime() {
        lock.lock()
        lastRequestTime = Date()
        lock.unlock()
    }
}

// MARK: - Errors
enum ArXivServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ArXiv API URL"
        case .invalidResponse:
            return "Invalid response from ArXiv"
        case .httpError(let statusCode):
            return "ArXiv API error (HTTP \(statusCode))"
        case .noData:
            return "No data received from ArXiv"
        }
    }
}

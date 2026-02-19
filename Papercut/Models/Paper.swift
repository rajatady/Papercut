//
//  Paper.swift
//  Papercut
//

import Foundation
import SwiftData

@Model
final class Paper {
    @Attribute(.unique) var id: String = "" // ArXiv ID
    var title: String = ""
    var abstract: String = ""
    var authorsData: Data = Data() // Encoded [Author]
    var categoriesData: Data = Data() // Encoded [String] - category codes
    var publishedDate: Date = Date()
    var updatedDate: Date = Date()
    var pdfURL: String = ""
    var abstractURL: String = ""
    var fetchedAt: Date = Date()

    @Relationship(deleteRule: .cascade) var summaries: [Summary] = []

    // SwiftData requires a default init
    init() {
        self.id = UUID().uuidString
        self.title = ""
        self.abstract = ""
        self.authorsData = Data()
        self.categoriesData = Data()
        self.publishedDate = Date()
        self.updatedDate = Date()
        self.pdfURL = ""
        self.abstractURL = ""
        self.fetchedAt = Date()
    }

    init(
        id: String,
        title: String,
        abstract: String,
        authors: [Author],
        categories: [String],
        publishedDate: Date,
        updatedDate: Date,
        pdfURL: String,
        abstractURL: String
    ) {
        self.id = id
        self.title = title
        self.abstract = abstract
        self.authorsData = (try? JSONEncoder().encode(authors)) ?? Data()
        self.categoriesData = (try? JSONEncoder().encode(categories)) ?? Data()
        self.publishedDate = publishedDate
        self.updatedDate = updatedDate
        self.pdfURL = pdfURL
        self.abstractURL = abstractURL
        self.fetchedAt = Date()
    }

    // MARK: - Computed Properties

    var authors: [Author] {
        get {
            (try? JSONDecoder().decode([Author].self, from: authorsData)) ?? []
        }
        set {
            authorsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var categories: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: categoriesData)) ?? []
        }
        set {
            categoriesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var primaryCategory: String? {
        categories.first
    }

    var formattedDate: String {
        publishedDate.formatted(date: .abbreviated, time: .omitted)
    }

    var isRecent: Bool {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        return publishedDate >= twoDaysAgo
    }
}

// MARK: - Summary Helpers
extension Paper {
    func summary(for style: SummaryStyle) -> Summary? {
        summaries.first { $0.style == style.rawValue }
    }

    func hasSummary(for style: SummaryStyle) -> Bool {
        summary(for: style) != nil
    }

    func addSummary(_ summary: Summary) {
        if let existingIndex = summaries.firstIndex(where: { $0.style == summary.style }) {
            summaries[existingIndex] = summary
        } else {
            summaries.append(summary)
        }
    }
}

// MARK: - ArXiv URL Helpers
extension Paper {
    var pdfURLObject: URL? {
        URL(string: pdfURL)
    }

    var abstractURLObject: URL? {
        URL(string: abstractURL)
    }

    var arXivId: String {
        // Extract just the numeric ID part (e.g., "2401.12345" from full URL)
        if let range = id.range(of: #"\d{4}\.\d{4,5}(v\d+)?"#, options: .regularExpression) {
            return String(id[range])
        }
        return id
    }
}

// MARK: - Stale Check
extension Paper {
    var isStale: Bool {
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        return fetchedAt < oneHourAgo
    }

    func markAsRefreshed() {
        fetchedAt = Date()
    }
}

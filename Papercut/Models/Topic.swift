//
//  Topic.swift
//  Papercut
//

import Foundation
import SwiftData

@Model
final class Topic {
    var id: String = ""
    var name: String = ""
    var query: String = ""
    var createdAt: Date = Date()
    var lastCheckedAt: Date? = nil
    var lastPaperCount: Int = 0
    var sortByRaw: String = "relevance"
    var isActive: Bool = true
    var paperIdsData: Data = Data()
    var scrollPosition: String? = nil
    var totalResults: Int = 0
    var isPopulating: Bool = false

    init() {
        self.id = UUID().uuidString
        self.name = ""
        self.query = ""
        self.createdAt = Date()
        self.lastCheckedAt = nil
        self.lastPaperCount = 0
        self.sortByRaw = "relevance"
        self.isActive = true
        self.paperIdsData = Data()
        self.scrollPosition = nil
        self.totalResults = 0
        self.isPopulating = false
    }

    init(name: String, query: String, sortBy: ArXivSortBy = .relevance) {
        self.id = UUID().uuidString
        self.name = name
        self.query = query
        self.createdAt = Date()
        self.lastCheckedAt = nil
        self.lastPaperCount = 0
        self.sortByRaw = sortBy.rawValue
        self.isActive = true
        self.paperIdsData = Data()
        self.scrollPosition = nil
        self.totalResults = 0
        self.isPopulating = false
    }
}

extension Topic {
    var sortBy: ArXivSortBy {
        ArXivSortBy(rawValue: sortByRaw) ?? .relevance
    }

    func setSortBy(_ value: ArXivSortBy) {
        sortByRaw = value.rawValue
    }

    var paperIds: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: paperIdsData)) ?? []
        }
        set {
            paperIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func appendPaperIds(_ ids: [String]) {
        var current = paperIds
        let existingSet = Set(current)
        let newIds = ids.filter { !existingSet.contains($0) }
        current.append(contentsOf: newIds)
        paperIds = current
    }

    func prependPaperIds(_ ids: [String]) {
        var current = paperIds
        let existingSet = Set(current)
        let newIds = ids.filter { !existingSet.contains($0) }
        paperIds = newIds + current
    }
}

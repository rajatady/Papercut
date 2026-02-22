//
//  TopicTests.swift
//  PapercutTests
//

import Testing
import Foundation
import SwiftData
@testable import Papercut

@Suite struct TopicTests {

    @Test func init_setsNameAndQuery() {
        let topic = Topic(name: "Transformers", query: "transformer attention")
        #expect(topic.name == "Transformers")
        #expect(topic.query == "transformer attention")
    }

    @Test func init_generatesUniqueId() {
        let a = Topic(name: "A", query: "a")
        let b = Topic(name: "B", query: "b")
        #expect(!a.id.isEmpty)
        #expect(!b.id.isEmpty)
        #expect(a.id != b.id)
    }

    @Test func init_defaultsToActive() {
        let topic = Topic(name: "Test", query: "test")
        #expect(topic.isActive == true)
    }

    @Test func init_sortByDefaultsToRelevance() {
        let topic = Topic(name: "Test", query: "test")
        #expect(topic.sortBy == .relevance)
    }

    @Test func sortBy_getterAndSetter() {
        let topic = Topic(name: "Test", query: "test")
        topic.setSortBy(.submittedDate)
        #expect(topic.sortBy == .submittedDate)
        #expect(topic.sortByRaw == "submittedDate")
    }

    @Test func init_setsCreatedAt() {
        let before = Date()
        let topic = Topic(name: "Test", query: "test")
        let after = Date()
        #expect(topic.createdAt >= before)
        #expect(topic.createdAt <= after)
    }

    @Test func init_lastCheckedAtIsNil() {
        let topic = Topic(name: "Test", query: "test")
        #expect(topic.lastCheckedAt == nil)
    }

    @Test func init_lastPaperCountIsZero() {
        let topic = Topic(name: "Test", query: "test")
        #expect(topic.lastPaperCount == 0)
    }

    @Test func init_withSortBy() {
        let topic = Topic(name: "Test", query: "test", sortBy: .lastUpdatedDate)
        #expect(topic.sortBy == .lastUpdatedDate)
    }

    // MARK: - Paper IDs (offline-first)

    @Test func paperIds_emptyByDefault() {
        let topic = Topic(name: "Test", query: "test")
        #expect(topic.paperIds.isEmpty)
    }

    @Test func paperIds_setAndGet() {
        let topic = Topic(name: "Test", query: "test")
        topic.paperIds = ["id1", "id2", "id3"]
        #expect(topic.paperIds == ["id1", "id2", "id3"])
    }

    @Test func appendPaperIds_addsNew() {
        let topic = Topic(name: "Test", query: "test")
        topic.paperIds = ["id1", "id2"]
        topic.appendPaperIds(["id3", "id4"])
        #expect(topic.paperIds == ["id1", "id2", "id3", "id4"])
    }

    @Test func appendPaperIds_deduplicates() {
        let topic = Topic(name: "Test", query: "test")
        topic.paperIds = ["id1", "id2"]
        topic.appendPaperIds(["id2", "id3"])
        #expect(topic.paperIds == ["id1", "id2", "id3"])
    }

    @Test func prependPaperIds_addsToFront() {
        let topic = Topic(name: "Test", query: "test")
        topic.paperIds = ["id2", "id3"]
        topic.prependPaperIds(["id0", "id1"])
        #expect(topic.paperIds == ["id0", "id1", "id2", "id3"])
    }

    @Test func prependPaperIds_deduplicates() {
        let topic = Topic(name: "Test", query: "test")
        topic.paperIds = ["id1", "id2"]
        topic.prependPaperIds(["id1", "id0"])
        #expect(topic.paperIds == ["id0", "id1", "id2"])
    }

    @Test func init_newFieldsHaveDefaults() {
        let topic = Topic(name: "Test", query: "test")
        #expect(topic.scrollPosition == nil)
        #expect(topic.totalResults == 0)
        #expect(topic.isPopulating == false)
        #expect(topic.paperIdsData == Data())
    }
}

//
//  AuthorTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct AuthorTests {

    // MARK: - Init

    @Test func init_withNameOnly() {
        let author = Author(name: "John Doe")
        #expect(author.name == "John Doe")
        #expect(author.affiliation == nil)
    }

    @Test func init_withAffiliation() {
        let author = Author(name: "Jane Smith", affiliation: "MIT")
        #expect(author.name == "Jane Smith")
        #expect(author.affiliation == "MIT")
    }

    // MARK: - Identifiable

    @Test func id_isName() {
        let author = Author(name: "Test Author")
        #expect(author.id == "Test Author")
    }

    // MARK: - Display Helpers

    @Test func displayName_returnsFullName() {
        let author = Author(name: "Alice Johnson")
        #expect(author.displayName == "Alice Johnson")
    }

    @Test func shortName_firstInitialAndLastName() {
        let author = Author(name: "Alice Johnson")
        #expect(author.shortName == "A. Johnson")
    }

    @Test func shortName_singleName_returnsAsIs() {
        let author = Author(name: "Madonna")
        #expect(author.shortName == "Madonna")
    }

    @Test func shortName_threePartName_usesFirstAndLast() {
        let author = Author(name: "Jean-Pierre Dupont")
        #expect(author.shortName == "J. Dupont")
    }

    // MARK: - Codable

    @Test func codable_roundTrip() throws {
        let original = Author(name: "Test", affiliation: "Stanford")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Author.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.affiliation == original.affiliation)
    }

    // MARK: - Hashable

    @Test func hashable_equalAuthorsHaveSameHash() {
        let a1 = Author(name: "Same Name")
        let a2 = Author(name: "Same Name")
        #expect(a1 == a2)
        #expect(a1.hashValue == a2.hashValue)
    }

    // MARK: - Array Display Extensions

    @Test func displayString_empty() {
        let authors: [Author] = []
        #expect(authors.displayString == "Unknown Authors")
    }

    @Test func displayString_oneAuthor() {
        let authors = [Author(name: "Alice")]
        #expect(authors.displayString == "Alice")
    }

    @Test func displayString_twoAuthors() {
        let authors = [Author(name: "Alice"), Author(name: "Bob")]
        #expect(authors.displayString == "Alice and Bob")
    }

    @Test func displayString_threeAuthors() {
        let authors = [Author(name: "Alice"), Author(name: "Bob"), Author(name: "Charlie")]
        #expect(authors.displayString == "Alice, Bob, and Charlie")
    }

    @Test func displayString_fourOrMoreAuthors() {
        let authors = [
            Author(name: "Alice"), Author(name: "Bob"),
            Author(name: "Charlie"), Author(name: "Diana")
        ]
        #expect(authors.displayString == "Alice, Bob, et al.")
    }

    @Test func shortDisplayString_empty() {
        let authors: [Author] = []
        #expect(authors.shortDisplayString == "Unknown")
    }

    @Test func shortDisplayString_oneAuthor() {
        let authors = [Author(name: "Alice Johnson")]
        #expect(authors.shortDisplayString == "A. Johnson")
    }

    @Test func shortDisplayString_multipleAuthors() {
        let authors = [Author(name: "Alice Johnson"), Author(name: "Bob Smith")]
        #expect(authors.shortDisplayString == "A. Johnson et al.")
    }
}

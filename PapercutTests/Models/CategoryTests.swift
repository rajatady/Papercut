//
//  CategoryTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite(.serialized)
struct CategoryTests {

    // MARK: - Init & Properties

    @Test func init_setsProperties() {
        let category = Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science")
        #expect(category.code == "cs.AI")
        #expect(category.name == "Artificial Intelligence")
        #expect(category.group == "Computer Science")
        #expect(category.id == "cs.AI")
    }

    // MARK: - Display Helpers

    @Test func displayName_returnsName() {
        let category = Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science")
        #expect(category.displayName == "Artificial Intelligence")
    }

    @Test func shortCode_replacesDotWithDash() {
        let category = Category(code: "cs.AI", name: "AI", group: "CS")
        #expect(category.shortCode == "cs-AI")
    }

    @Test func shortCode_handlesMultipleDots() {
        let category = Category(code: "physics.comp-ph", name: "Computational Physics", group: "Physics")
        #expect(category.shortCode == "physics-comp-ph")
    }

    @Test func arXivQueryCode_returnsCode() {
        let category = Category(code: "stat.ML", name: "ML", group: "Statistics")
        #expect(category.arXivQueryCode == "stat.ML")
    }

    // MARK: - Search

    @Test func matches_emptySearchReturnsTrue() {
        let category = Category(code: "cs.AI", name: "AI", group: "CS")
        #expect(category.matches(searchText: "") == true)
    }

    @Test func matches_byCode() {
        let category = Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science")
        #expect(category.matches(searchText: "cs.AI") == true)
        #expect(category.matches(searchText: "cs.a") == true) // case insensitive
    }

    @Test func matches_byName() {
        let category = Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science")
        #expect(category.matches(searchText: "artificial") == true)
        #expect(category.matches(searchText: "intelligence") == true)
    }

    @Test func matches_byGroup() {
        let category = Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science")
        #expect(category.matches(searchText: "computer") == true)
    }

    @Test func matches_noMatch() {
        let category = Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science")
        #expect(category.matches(searchText: "physics") == false)
    }

    // MARK: - Codable

    @Test func codable_roundTrip() throws {
        let original = Category(code: "cs.AI", name: "AI", group: "CS")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Category.self, from: data)

        #expect(decoded.code == original.code)
        #expect(decoded.name == original.name)
        #expect(decoded.group == original.group)
    }

    // MARK: - Hashable

    @Test func hashable_equalCategoriesMatch() {
        let a = Category(code: "cs.AI", name: "AI", group: "CS")
        let b = Category(code: "cs.AI", name: "AI", group: "CS")
        #expect(a == b)
    }
}

// MARK: - CategoryGroup Tests

@Suite(.serialized)
struct CategoryGroupTests {

    @Test func allCases_containsEightGroups() {
        #expect(CategoryGroup.allCases.count == 8)
    }

    @Test func abbreviations_correct() {
        #expect(CategoryGroup.physics.abbreviation == "physics")
        #expect(CategoryGroup.mathematics.abbreviation == "math")
        #expect(CategoryGroup.computerScience.abbreviation == "cs")
        #expect(CategoryGroup.quantitativeBiology.abbreviation == "q-bio")
        #expect(CategoryGroup.quantitativeFinance.abbreviation == "q-fin")
        #expect(CategoryGroup.statistics.abbreviation == "stat")
        #expect(CategoryGroup.electricalEngineering.abbreviation == "eess")
        #expect(CategoryGroup.economics.abbreviation == "econ")
    }

    @Test func rawValues_areHumanReadable() {
        #expect(CategoryGroup.computerScience.rawValue == "Computer Science")
        #expect(CategoryGroup.physics.rawValue == "Physics")
    }
}

// MARK: - CategoryManager Tests

@Suite(.serialized)
struct CategoryManagerTests {

    @MainActor
    @Test func defaultCategories_containsExpectedEntries() {
        let defaults = CategoryManager.defaultCategories
        #expect(!defaults.isEmpty)
        #expect(defaults.contains { $0.code == "cs.AI" })
        #expect(defaults.contains { $0.code == "cs.LG" })
        #expect(defaults.contains { $0.code == "stat.ML" })
    }

    @MainActor
    @Test func defaultCategories_haveValidGroups() {
        for category in CategoryManager.defaultCategories {
            #expect(!category.group.isEmpty)
        }
    }
}

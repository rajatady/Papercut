//
//  Category.swift
//  Papercut
//

import Foundation

struct Category: Codable, Hashable, Identifiable {
    let code: String
    let name: String
    let group: String

    var id: String { code }

    init(code: String, name: String, group: String) {
        self.code = code
        self.name = name
        self.group = group
    }
}

// MARK: - Display Helpers
extension Category {
    var displayName: String {
        name
    }

    var shortCode: String {
        code.replacingOccurrences(of: ".", with: "-")
    }

    var arXivQueryCode: String {
        code
    }
}

// MARK: - Search
extension Category {
    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        let lowercasedSearch = searchText.lowercased()
        return code.lowercased().contains(lowercasedSearch) ||
               name.lowercased().contains(lowercasedSearch) ||
               group.lowercased().contains(lowercasedSearch)
    }
}

// MARK: - Category Groups
enum CategoryGroup: String, CaseIterable {
    case physics = "Physics"
    case mathematics = "Mathematics"
    case computerScience = "Computer Science"
    case quantitativeBiology = "Quantitative Biology"
    case quantitativeFinance = "Quantitative Finance"
    case statistics = "Statistics"
    case electricalEngineering = "Electrical Engineering and Systems Science"
    case economics = "Economics"

    var abbreviation: String {
        switch self {
        case .physics: return "physics"
        case .mathematics: return "math"
        case .computerScience: return "cs"
        case .quantitativeBiology: return "q-bio"
        case .quantitativeFinance: return "q-fin"
        case .statistics: return "stat"
        case .electricalEngineering: return "eess"
        case .economics: return "econ"
        }
    }
}

// MARK: - Category Manager
@MainActor
final class CategoryManager {
    static let shared = CategoryManager()

    private(set) var allCategories: [Category] = []

    private init() {
        loadCategories()
    }

    private func loadCategories() {
        guard let url = Bundle.main.url(forResource: "ArXivCategories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([Category].self, from: data) else {
            // Fallback to default categories if file not found
            allCategories = Self.defaultCategories
            return
        }
        allCategories = categories
    }

    func categories(for group: CategoryGroup) -> [Category] {
        allCategories.filter { $0.group == group.rawValue }
    }

    func search(_ query: String) -> [Category] {
        guard !query.isEmpty else { return allCategories }
        return allCategories.filter { $0.matches(searchText: query) }
    }

    func category(forCode code: String) -> Category? {
        allCategories.first { $0.code == code }
    }

    // Default popular categories for fallback
    static let defaultCategories: [Category] = [
        Category(code: "cs.AI", name: "Artificial Intelligence", group: "Computer Science"),
        Category(code: "cs.LG", name: "Machine Learning", group: "Computer Science"),
        Category(code: "cs.CL", name: "Computation and Language", group: "Computer Science"),
        Category(code: "cs.CV", name: "Computer Vision and Pattern Recognition", group: "Computer Science"),
        Category(code: "cs.NE", name: "Neural and Evolutionary Computing", group: "Computer Science"),
        Category(code: "cs.RO", name: "Robotics", group: "Computer Science"),
        Category(code: "cs.SE", name: "Software Engineering", group: "Computer Science"),
        Category(code: "cs.CR", name: "Cryptography and Security", group: "Computer Science"),
        Category(code: "cs.DB", name: "Databases", group: "Computer Science"),
        Category(code: "cs.DC", name: "Distributed, Parallel, and Cluster Computing", group: "Computer Science"),
        Category(code: "cs.HC", name: "Human-Computer Interaction", group: "Computer Science"),
        Category(code: "cs.IR", name: "Information Retrieval", group: "Computer Science"),
        Category(code: "cs.PL", name: "Programming Languages", group: "Computer Science"),
        Category(code: "stat.ML", name: "Machine Learning", group: "Statistics"),
        Category(code: "math.OC", name: "Optimization and Control", group: "Mathematics"),
        Category(code: "physics.comp-ph", name: "Computational Physics", group: "Physics"),
        Category(code: "q-bio.NC", name: "Neurons and Cognition", group: "Quantitative Biology"),
        Category(code: "econ.GN", name: "General Economics", group: "Economics"),
    ]
}

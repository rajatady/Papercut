//
//  Author.swift
//  Papercut
//

import Foundation

struct Author: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let affiliation: String?

    init(name: String, affiliation: String? = nil) {
        self.name = name
        self.affiliation = affiliation
    }
}

// MARK: - Display Helpers
extension Author {
    var displayName: String {
        name
    }

    var shortName: String {
        let components = name.split(separator: " ")
        guard components.count > 1 else { return name }
        let firstInitial = components.first?.prefix(1) ?? ""
        let lastName = components.last ?? ""
        return "\(firstInitial). \(lastName)"
    }
}

// MARK: - Array Extension for Author Display
extension Array where Element == Author {
    var displayString: String {
        switch count {
        case 0:
            return "Unknown Authors"
        case 1:
            return self[0].displayName
        case 2:
            return "\(self[0].displayName) and \(self[1].displayName)"
        case 3:
            return "\(self[0].displayName), \(self[1].displayName), and \(self[2].displayName)"
        default:
            return "\(self[0].displayName), \(self[1].displayName), et al."
        }
    }

    var shortDisplayString: String {
        switch count {
        case 0:
            return "Unknown"
        case 1:
            return self[0].shortName
        default:
            return "\(self[0].shortName) et al."
        }
    }
}

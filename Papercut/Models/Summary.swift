//
//  Summary.swift
//  Papercut
//

import Foundation
import SwiftData

@Model
final class Summary {
    @Attribute(.unique) var id: String = ""
    var paperId: String = ""
    var style: String = "" // SummaryStyle.rawValue
    var content: String = ""
    var createdAt: Date = Date()
    var isComplete: Bool = false

    // SwiftData requires a default init
    init() {
        self.id = UUID().uuidString
        self.paperId = ""
        self.style = SummaryStyle.tldr.rawValue
        self.content = ""
        self.createdAt = Date()
        self.isComplete = false
    }

    init(
        paperId: String,
        style: SummaryStyle,
        content: String = "",
        isComplete: Bool = false
    ) {
        self.id = "\(paperId)_\(style.rawValue)"
        self.paperId = paperId
        self.style = style.rawValue
        self.content = content
        self.createdAt = Date()
        self.isComplete = isComplete
    }

    var summaryStyle: SummaryStyle? {
        SummaryStyle(rawValue: style)
    }
}

// MARK: - Summary Key
extension Summary {
    static func makeId(paperId: String, style: SummaryStyle) -> String {
        "\(paperId)_\(style.rawValue)"
    }
}

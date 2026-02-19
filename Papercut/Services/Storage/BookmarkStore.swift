//
//  BookmarkStore.swift
//  Papercut
//

import Foundation

@Observable
final class BookmarkStore {
    static let shared = BookmarkStore()

    private let key = "bookmarkedPaperIds"
    private(set) var bookmarkedIds: Set<String> = []

    private init() {
        load()
    }

    func isBookmarked(_ paperId: String) -> Bool {
        bookmarkedIds.contains(paperId)
    }

    func toggle(_ paperId: String) {
        if bookmarkedIds.contains(paperId) {
            bookmarkedIds.remove(paperId)
        } else {
            bookmarkedIds.insert(paperId)
        }
        save()
    }

    func bookmark(_ paperId: String) {
        bookmarkedIds.insert(paperId)
        save()
    }

    func unbookmark(_ paperId: String) {
        bookmarkedIds.remove(paperId)
        save()
    }

    private func load() {
        if let array = UserDefaults.standard.stringArray(forKey: key) {
            bookmarkedIds = Set(array)
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(bookmarkedIds), forKey: key)
    }
}

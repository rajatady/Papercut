//
//  NotificationType.swift
//  Papercut
//

import Foundation

enum NotificationType: String, Codable, CaseIterable {
    case dailyDigest = "daily_digest"
    case topicUpdate = "topic_update"
    case newFeedItems = "new_feed_items"

    var categoryIdentifier: String { rawValue }
}

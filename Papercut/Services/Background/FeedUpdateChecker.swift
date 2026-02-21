//
//  FeedUpdateChecker.swift
//  Papercut
//

import Foundation
import UserNotifications

@MainActor
struct FeedUpdateChecker {
    let paperRepository: PaperRepository
    let preferencesStore: PreferencesStore

    func run() async {
        let categories = preferencesStore.followedCategories
        guard !categories.isEmpty else { return }

        do {
            let papers = try await paperRepository.fetchPapers(
                categories: categories,
                page: 0,
                forceRefresh: true,
                mode: .latest
            )

            let lastKnownId = preferencesStore.lastKnownLatestPaperId

            if let lastKnownId {
                if let idx = papers.firstIndex(where: { $0.id == lastKnownId }) {
                    let newCount = idx // papers before the last known one are new
                    if newCount > 0 {
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = NotificationRequest(
                            type: .newFeedItems,
                            title: "New Research Available",
                            body: "\(newCount) new paper\(newCount == 1 ? "" : "s") in your feed",
                            trigger: trigger,
                            userInfo: ["type": "new_feed_items", "count": newCount]
                        )
                        NotificationManager.shared.schedule(request)
                    }
                } else {
                    // Last known paper not in results — all papers are new
                    if !papers.isEmpty {
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = NotificationRequest(
                            type: .newFeedItems,
                            title: "New Research Available",
                            body: "\(papers.count) new paper\(papers.count == 1 ? "" : "s") in your feed",
                            trigger: trigger,
                            userInfo: ["type": "new_feed_items", "count": papers.count]
                        )
                        NotificationManager.shared.schedule(request)
                    }
                }
            }

            // Update last known
            if let first = papers.first {
                preferencesStore.setLastKnownLatestPaperId(first.id)
            }
        } catch {
            // Silently fail — background tasks shouldn't crash
        }
    }
}

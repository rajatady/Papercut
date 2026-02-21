//
//  TopicUpdateChecker.swift
//  Papercut
//

import Foundation
import UserNotifications

@MainActor
struct TopicUpdateChecker {
    let topicRepository: TopicRepository
    let notificationManager: NotificationManager

    func run() async {
        let topics = topicRepository.fetchAllTopics()

        for topic in topics where topic.isActive {
            do {
                let newCount = try await topicRepository.checkForNewPapers(topic)
                if newCount > 0 {
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let request = NotificationRequest(
                        type: .topicUpdate,
                        title: topic.name,
                        body: "\(newCount) new paper\(newCount == 1 ? "" : "s") found",
                        trigger: trigger,
                        userInfo: ["type": "topic_update", "topicId": topic.id],
                        customIdentifier: "topic_update_\(topic.id)"
                    )
                    notificationManager.schedule(request)
                }
            } catch {
                // Don't let one topic failure block others
                continue
            }
        }
    }
}

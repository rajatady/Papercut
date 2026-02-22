//
//  NotificationRequest.swift
//  Papercut
//

import Foundation
import UserNotifications

struct NotificationRequest {
    let type: NotificationType
    let title: String
    let body: String
    let trigger: UNNotificationTrigger
    let userInfo: [String: Any]
    let customIdentifier: String?

    init(
        type: NotificationType,
        title: String,
        body: String,
        trigger: UNNotificationTrigger,
        userInfo: [String: Any],
        customIdentifier: String? = nil
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.trigger = trigger
        self.userInfo = userInfo
        self.customIdentifier = customIdentifier
    }

    var identifier: String { customIdentifier ?? type.rawValue }
}

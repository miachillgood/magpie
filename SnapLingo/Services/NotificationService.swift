//
//  NotificationService.swift
//  SnapLingo
//

import Foundation
import UserNotifications

/// 每日学习提醒
enum NotificationService {
    private static let prefix = "daily-study-reminder-"
    private static let daysAhead = 7

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 重新安排未来 7 天的提醒。今天已完成计划时跳过今天
    /// - Parameter pendingCount: 今天还剩多少个词（用于今天那条提醒的文案）
    static func reschedule(enabled: Bool, hour: Int, minute: Int, pendingCount: Int, completedToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<daysAhead).map { "\(prefix)\($0)" })
        guard enabled else { return }

        let calendar = Calendar.current
        let now = Date()
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now else { continue }
            if offset == 0 && completedToday { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "今天的单词在等你")
            if offset == 0 && pendingCount > 0 {
                content.body = String(localized: "还有 \(pendingCount) 个词，花几分钟就能完成今日计划。")
            } else {
                content.body = String(localized: "复习几分钟，再拍下身边的一个英文场景吧。")
            }
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: "\(prefix)\(offset)", content: content, trigger: trigger))
        }
    }
}

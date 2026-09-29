//
//  HomeMood.swift
//  SnapLingo
//
//  首页顶部随用户当天的状态变化：换一种柔光色、一句话和一个按钮。
//  这里只放纯逻辑（选状态、日期怎么叫、按天分组），方便测试。
//

import Foundation

/// 首页顶部显示哪种状态
enum HomeMood: String, CaseIterable, Sendable {
    /// 今天拍过：刚刚在公交站捡到 5 个新词
    case captured
    /// 今天还没拍，有要复习的词：昨天在公交站遇见 5 个词，还记得几个？
    case review
    /// 周末：这周你在 5 个地方发现了 16 个词
    case weekly
    /// 今天还没拍，也没有要复习的：今天还没发现新单词
    case empty

    /// 优先级：今天拍过 > 有待复习 > 周末回顾 > 还没拍
    static func pick(
        scannedToday: Bool,
        pendingStudy: Int,
        scansThisWeek: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeMood {
        if scannedToday { return .captured }
        if pendingStudy > 0 { return .review }
        if calendar.isDateInWeekend(now) && scansThisWeek > 0 { return .weekly }
        return .empty
    }
}

enum HomeDates {
    private static let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    /// 一周内的日子叫“今天 / 昨天 / 周六”，再早的返回 nil（只显示日期）
    static func dayName(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String? {
        let days = daysBetween(date, now, calendar: calendar)
        switch days {
        case 0: return "今天"
        case 1: return "昨天"
        case 2...6: return weekdays[calendar.component(.weekday, from: date) - 1]
        default: return nil
        }
    }

    /// “9 月 28 日”；不是今年时带上年份
    static func dateText(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let text = "\(parts.month ?? 0) 月 \(parts.day ?? 0) 日"
        guard parts.year != calendar.component(.year, from: now) else { return text }
        return "\(parts.year ?? 0) 年 " + text
    }

    /// 句子开头的“什么时候”：刚刚 / 今天 / 昨天 / 周六 / 9 月 23 日
    static func whenPhrase(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now), now.timeIntervalSince(date) < 90 * 60 {
            return "刚刚"
        }
        return dayName(for: date, now: now, calendar: calendar) ?? dateText(for: date, now: now, calendar: calendar)
    }

    /// 按天分组，新的日子在前，组内保持原顺序
    static func groupByDay<Item>(_ items: [Item], calendar: Calendar = .current, date: (Item) -> Date) -> [(day: Date, items: [Item])] {
        var order: [Date] = []
        var groups: [Date: [Item]] = [:]
        for item in items {
            let day = calendar.startOfDay(for: date(item))
            if groups[day] == nil { order.append(day) }
            groups[day, default: []].append(item)
        }
        return order.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    private static func daysBetween(_ date: Date, _ now: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

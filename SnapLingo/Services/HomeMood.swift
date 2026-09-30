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
    /// 一周内的日子叫“今天 / 昨天 / 周六”，再早的返回 nil（只显示日期）
    static func dayName(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String? {
        let days = daysBetween(date, now, calendar: calendar)
        switch days {
        case 0: return String(localized: "今天")
        case 1: return String(localized: "昨天")
        case 2...6: return weekday(for: date, calendar: calendar, locale: locale)
        default: return nil
        }
    }

    /// 星期几：周六 / Saturday / 土曜日 / 토요일 / sábado
    static func weekday(for date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        // 中文用“周六”，其它语言用完整写法
        let width: Date.FormatStyle.Symbol.Weekday = locale.language.languageCode == .chinese ? .abbreviated : .wide
        return date.formatted(style(calendar: calendar, locale: locale).weekday(width))
    }

    /// 最窄的星期写法，放在一周的小圆环上面：六 / S / 土 / 토
    static func narrowWeekday(for date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(style(calendar: calendar, locale: locale).weekday(.narrow))
    }

    /// 月份名：9月 / September / 9月 / 9월 / Septiembre（中文用“9月”，不用“九月”）
    static func monthName(for date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let width: Date.FormatStyle.Symbol.Month = locale.language.languageCode == .chinese ? .abbreviated : .wide
        let name = date.formatted(style(calendar: calendar, locale: locale).month(width))
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    /// 以后的日子怎么叫：明天 / 后天 / 周四 / 10月8日
    static func upcomingName(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = daysBetween(now, date, calendar: calendar)
        switch days {
        case 0: return String(localized: "今天")
        case 1: return String(localized: "明天")
        case 2: return String(localized: "后天", comment: "The day after tomorrow")
        case 3...6: return weekday(for: date, calendar: calendar, locale: locale)
        default: return dateText(for: date, now: now, calendar: calendar, locale: locale)
        }
    }

    /// “9月28日” / “Sep 28”；不是今年时带上年份
    static func dateText(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        var format = style(calendar: calendar, locale: locale).month(.abbreviated).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
            format = format.year()
        }
        return date.formatted(format)
    }

    /// 句子开头的“什么时候”：刚刚 / 今天 / 昨天 / 周六 / 9 月 23 日
    static func whenPhrase(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now), now.timeIntervalSince(date) < 90 * 60 {
            return String(localized: "刚刚", comment: "Just now (happened within the last hour or so)")
        }
        return dayName(for: date, now: now, calendar: calendar, locale: locale)
            ?? dateText(for: date, now: now, calendar: calendar, locale: locale)
    }

    private static func style(calendar: Calendar, locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
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

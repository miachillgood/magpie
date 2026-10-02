//
//  HomeMood.swift
//  SnapLingo
//
//  首页顶部随用户当天的状态变化：换一种柔光色、一句话和一个按钮。
//  这里只放纯逻辑（选状态、日期怎么叫、按天分组），方便测试。
//

import Foundation

/// 首页顶部显示哪种状态：跟着最近一次拍照的那一天走，不是每天都用也总有内容
enum HomeMood: String, CaseIterable, Sendable {
    /// 今天拍过：今天在 3 个场景捡到 12 个词
    case today
    /// 最近一次是 1–7 天前：周六在公交站捡到 5 个词
    case recent
    /// 超过一周没拍：上次是 9 月 20 日，好久不见
    case away
    /// 从没拍过：拍下你的第一块招牌
    case empty

    /// 超过这么多天算“好久不见”
    static let awayAfterDays = 7

    static func pick(latestScanDate: Date?, now: Date = Date(), calendar: Calendar = .current) -> HomeMood {
        guard let latestScanDate else { return .empty }
        switch HomeDates.daysBetween(latestScanDate, now, calendar: calendar) {
        case ...0: return .today
        case 1...awayAfterDays: return .recent
        default: return .away
        }
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

    static func daysBetween(_ date: Date, _ now: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

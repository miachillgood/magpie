//
//  ReviewDays.swift
//  SnapLingo
//
//  复习页的日期线索：每一天拍了几个场景、存了几个词、有没有复习。
//  只放纯逻辑，方便测试；视图层把 Scan / ReviewLog 转成这里的输入。
//

import Foundation

/// 某一次拍摄在日期线索里需要的信息
struct CaptureRecord: Sendable {
    var date: Date
    var wordIDs: Set<UUID>
}

struct ReviewDay: Identifiable, Equatable, Sendable {
    /// 当天 0 点
    var date: Date
    var scanCount: Int
    /// 当天拍到并保存的词（去重）
    var wordCount: Int
    /// 当天复习（评分）了几次
    var reviewCount: Int
    var id: Date { date }

    var hasCaptures: Bool { scanCount > 0 }
    var reviewed: Bool { reviewCount > 0 }

    /// 复习圆环的进度：达到每日目标就满环
    func reviewProgress(goal: Int) -> Double {
        min(1, Double(reviewCount) / Double(max(goal, 1)))
    }

    /// 圆点深浅：0 = 没拍，1 = 1–3 个词，2 = 4–7 个词，3 = 8 个词及以上
    var shade: Int {
        guard hasCaptures else { return 0 }
        switch wordCount {
        case ..<4: return 1
        case ..<8: return 2
        default: return 3
        }
    }
}

enum ReviewDays {
    /// 截止到 end 那天（含）的最近 count 天，早的在前
    static func recent(
        count: Int,
        endingAt end: Date = Date(),
        captures: [CaptureRecord],
        reviewDates: [Date],
        calendar: Calendar = .current
    ) -> [ReviewDay] {
        let last = calendar.startOfDay(for: end)
        let days = (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: last) }
        return build(days: days, captures: captures, reviewDates: reviewDates, calendar: calendar)
    }

    /// date 所在月份的每一天
    static func month(
        containing date: Date,
        captures: [CaptureRecord],
        reviewDates: [Date],
        calendar: Calendar = .current
    ) -> [ReviewDay] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return build(days: days, captures: captures, reviewDates: reviewDates, calendar: calendar)
    }

    /// 月历第一行前面要空几格（按日历的一周起始日）
    static func leadingBlanks(forMonthContaining date: Date, calendar: Calendar = .current) -> Int {
        guard let start = calendar.dateInterval(of: .month, for: date)?.start else { return 0 }
        let weekday = calendar.component(.weekday, from: start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private static func build(days: [Date], captures: [CaptureRecord], reviewDates: [Date], calendar: Calendar) -> [ReviewDay] {
        var scansByDay: [Date: Int] = [:]
        var wordsByDay: [Date: Set<UUID>] = [:]
        for capture in captures {
            let day = calendar.startOfDay(for: capture.date)
            scansByDay[day, default: 0] += 1
            wordsByDay[day, default: []].formUnion(capture.wordIDs)
        }
        var reviewsByDay: [Date: Int] = [:]
        for date in reviewDates {
            reviewsByDay[calendar.startOfDay(for: date), default: 0] += 1
        }
        return days.map { day in
            ReviewDay(
                date: day,
                scanCount: scansByDay[day] ?? 0,
                wordCount: wordsByDay[day]?.count ?? 0,
                reviewCount: reviewsByDay[day] ?? 0
            )
        }
    }
}

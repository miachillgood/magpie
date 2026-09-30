//
//  DailyPlanner.swift
//  SnapLingo
//

import Foundation

/// 计划需要的单词字段（VocabWord 遵循；测试里可以用轻量结构体）
protocol PlannableWord {
    var id: UUID { get }
    var state: WordState { get }
    var excludedFromReview: Bool { get }
    var dueDate: Date { get }
    var addedAt: Date { get }
    var easeFactor: Double { get }
}

/// 计划需要的学习记录字段
protocol StudyEvent {
    var wordID: UUID { get }
    var reviewedAt: Date { get }
    var wasNew: Bool { get }
}

extension VocabWord: PlannableWord {}

extension PlannableWord {
    /// 学过、没被排除、今天或之前到期
    func isDue(today: Date) -> Bool {
        !excludedFromReview && state != .new && dueDate <= today
    }

    /// 现在可以学：新词，或已经到期
    func isStudyable(today: Date) -> Bool {
        !excludedFromReview && (state == .new || dueDate <= today)
    }
}
extension ReviewLog: StudyEvent {}

/// 今日计划
struct DailyPlan: Equatable, Sendable {
    /// 今天待复习（最逾期的在前）
    var reviewIDs: [UUID]
    /// 今天要学的新词（最近保存的在前）
    var newIDs: [UUID]
    var reviewsDone: Int
    var newDone: Int

    static let empty = DailyPlan(reviewIDs: [], newIDs: [], reviewsDone: 0, newDone: 0)

    var reviewTarget: Int { reviewsDone + reviewIDs.count }
    var newTarget: Int { newDone + newIDs.count }
    var remaining: Int { reviewIDs.count + newIDs.count }
    var doneToday: Int { reviewsDone + newDone }
    var hasWork: Bool { remaining > 0 }
    var isComplete: Bool { remaining == 0 && doneToday > 0 }

    /// 某一项今天本来就没有任务时，计划完成后这一圈也算闭合
    var reviewProgress: Double { reviewTarget == 0 && isComplete ? 1 : DailyPlan.progress(done: reviewsDone, target: reviewTarget) }
    var newProgress: Double { newTarget == 0 && isComplete ? 1 : DailyPlan.progress(done: newDone, target: newTarget) }
    var overallProgress: Double { DailyPlan.progress(done: doneToday, target: doneToday + remaining) }

    private static func progress(done: Int, target: Int) -> Double {
        target == 0 ? (done > 0 ? 1 : 0) : min(Double(done) / Double(target), 1)
    }
}

/// 某一天的到期数量
struct ForecastDay: Identifiable, Equatable, Sendable {
    var date: Date
    var count: Int
    var id: Date { date }
}

enum DailyPlanner {

    /// 生成今天的计划
    /// - Parameters:
    ///   - extraNew: 今天额外多学的新词数（“再学几个”）
    static func plan<W: PlannableWord, E: StudyEvent>(
        words: [W],
        events: [E],
        newPerDay: Int,
        maxReviews: Int,
        extraNew: Int = 0,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyPlan {
        let today = calendar.startOfDay(for: now)
        let todays = events.filter { calendar.isDate($0.reviewedAt, inSameDayAs: now) }
        let newDoneIDs = Set(todays.filter(\.wasNew).map(\.wordID))
        let reviewDoneIDs = Set(todays.filter { !$0.wasNew }.map(\.wordID)).subtracting(newDoneIDs)

        let due = words
            .filter { $0.state != .new && !$0.excludedFromReview && $0.dueDate <= today && !reviewDoneIDs.contains($0.id) && !newDoneIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
                return lhs.easeFactor < rhs.easeFactor
            }
        let reviewQuota = max(0, maxReviews - reviewDoneIDs.count)

        let newQuota = max(0, newPerDay + extraNew - newDoneIDs.count)
        let fresh = words
            .filter { $0.state == .new && !$0.excludedFromReview }
            .sorted { $0.addedAt > $1.addedAt }

        return DailyPlan(
            reviewIDs: Array(due.prefix(reviewQuota).map(\.id)),
            newIDs: Array(fresh.prefix(newQuota).map(\.id)),
            reviewsDone: reviewDoneIDs.count,
            newDone: newDoneIDs.count
        )
    }

    /// 连续学习天数（今天还没学时，从昨天往前算）
    static func streak<E: StudyEvent>(events: [E], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(events.map { calendar.startOfDay(for: $0.reviewedAt) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// 历史上最长连续学习了几天
    static func longestStreak<E: StudyEvent>(events: [E], calendar: Calendar = .current) -> Int {
        let days = Set(events.map { calendar.startOfDay(for: $0.reviewedAt) }).sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous), calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// 未来几天的复习量（第 0 天包含已逾期的）
    static func forecast<W: PlannableWord>(words: [W], days: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [ForecastDay] {
        let today = calendar.startOfDay(for: now)
        let active = words.filter { $0.state != .new && !$0.excludedFromReview }
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let count = active.filter { word in
                let due = calendar.startOfDay(for: word.dueDate)
                return offset == 0 ? due <= day : due == day
            }.count
            return ForecastDay(date: day, count: count)
        }
    }

    /// 某天之后第一次有复习的日子和数量，用于“明天有 N 个复习”
    static func nextReviewDay<W: PlannableWord>(words: [W], after now: Date = Date(), calendar: Calendar = .current) -> ForecastDay? {
        let today = calendar.startOfDay(for: now)
        let upcoming = words
            .filter { $0.state != .new && !$0.excludedFromReview }
            .map { calendar.startOfDay(for: $0.dueDate) }
            .filter { $0 > today }
        guard let first = upcoming.min() else { return nil }
        return ForecastDay(date: first, count: upcoming.filter { $0 == first }.count)
    }
}

//
//  MeStats.swift
//  SnapLingo
//
//  长期统计：来了多少天、错词重练。
//  只放纯逻辑，方便测试；视图层把 Scan / VocabWord 转成这里的输入。
//

import Foundation

/// 错词重练要看的单词字段
struct MistakeRecord: Sendable {
    var id: UUID
    var mistakeAt: Date?
    var excludedFromReview: Bool
}

/// 学习进度要看的单词字段
struct ProgressRecord: Sendable {
    var id: UUID
    var state: WordState
    var excludedFromReview: Bool
}

/// 一次评分之后排到了几天后
struct IntervalEvent: Sendable {
    var wordID: UUID
    var reviewedAt: Date
    var intervalAfter: Int
}

/// 复习页底部「我的进度」：四段加起来等于总词数
struct LearningProgress: Equatable, Sendable {
    var new = 0
    var learning = 0
    /// 复习到间隔 ≥ 21 天的
    var mastered = 0
    /// 点「太简单」移出复习的，单独算，不算进已掌握
    var tooEasy = 0
    /// 最近 7 天第一次复习到 ≥ 21 天间隔的词
    var masteredThisWeek = 0

    var total: Int { new + learning + mastered + tooEasy }
}

enum MeStats {
    static func progress(
        words: [ProgressRecord],
        events: [IntervalEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LearningProgress {
        var result = LearningProgress()
        for word in words {
            if word.excludedFromReview { result.tooEasy += 1; continue }
            switch word.state {
            case .new:      result.new += 1
            case .learning: result.learning += 1
            case .mastered: result.mastered += 1
            }
        }
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        var firstMastered: [UUID: Date] = [:]
        for event in events where event.intervalAfter >= SpacedRepetition.masteredThreshold {
            if let seen = firstMastered[event.wordID], seen <= event.reviewedAt { continue }
            firstMastered[event.wordID] = event.reviewedAt
        }
        result.masteredThisWeek = firstMastered.values.filter { $0 >= weekStart && $0 <= now }.count
        return result
    }

    /// 从第一次拍照那天算起是第几天（当天算第 1 天）；还没拍过返回 0
    static func daysSinceFirst(_ dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let first = dates.min() else { return 0 }
        let start = calendar.startOfDay(for: first)
        let today = calendar.startOfDay(for: now)
        return max(1, (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
    }

    /// 错词：最近一次点了「不会」、之后还没答对、还在复习的词，最近错的在前
    static func mistakeWordIDs(_ records: [MistakeRecord]) -> [UUID] {
        records
            .compactMap { record in record.excludedFromReview ? nil : record.mistakeAt.map { (record.id, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// 评分之后的错词标记：「不会」记下时间，答对就清掉
    static func mistakeAt(after rating: ReviewRating, previous: Date?, now: Date) -> Date? {
        rating.isSuccess ? nil : now
    }
}

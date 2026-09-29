//
//  SpacedRepetitionService.swift
//  SnapLingo
//

import Foundation

/// 一个词的复习状态（纯值类型，方便测试）
struct SRSState: Equatable, Sendable {
    var state: WordState
    var easeFactor: Double
    var intervalDays: Int
    var repetitions: Int
    var lapses: Int
    var dueDate: Date

    static func fresh(on date: Date, calendar: Calendar = .current) -> SRSState {
        SRSState(state: .new, easeFactor: 2.5, intervalDays: 0, repetitions: 0, lapses: 0, dueDate: calendar.startOfDay(for: date))
    }
}

/// SM-2 变体：按自然日安排复习
///
/// - 忘了：连续次数清零，明天再见，难度系数 -0.2
/// - 前两次答对用固定短间隔（1 天、3 天），之后按「间隔 × 难度系数」增长
/// - 间隔 ≥ 21 天视为已掌握（仍会按期复习）
enum SpacedRepetition {
    static let masteredThreshold = 21
    static let maxInterval = 365
    static let minEase = 1.3

    static func schedule(
        _ current: SRSState,
        rating: ReviewRating,
        on date: Date,
        calendar: Calendar = .current
    ) -> SRSState {
        var next = current
        let today = calendar.startOfDay(for: date)

        if rating == .again {
            if current.state != .new { next.lapses += 1 }
            next.repetitions = 0
            next.intervalDays = 1
            next.easeFactor = max(minEase, current.easeFactor - 0.2)
        } else {
            let interval: Int
            switch current.repetitions {
            case 0:
                interval = rating == .easy ? 4 : 1
            case 1:
                switch rating {
                case .hard: interval = 2
                case .easy: interval = 6
                default:    interval = 3
                }
            default:
                let base = Double(max(current.intervalDays, 1))
                let good = max(current.intervalDays + 1, Int((base * current.easeFactor).rounded()))
                switch rating {
                case .hard:
                    interval = min(good, max(current.intervalDays + 1, Int((base * 1.2).rounded())))
                case .easy:
                    // “太简单”一定比“认识”排得更远
                    interval = max(good + 1, Int((base * current.easeFactor * 1.3).rounded()))
                default:
                    interval = good
                }
            }
            next.intervalDays = min(interval, maxInterval)
            next.repetitions = current.repetitions + 1

            let q = Double(rating.rawValue)
            let delta = 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)
            next.easeFactor = max(minEase, current.easeFactor + delta)
        }

        next.dueDate = calendar.date(byAdding: .day, value: next.intervalDays, to: today) ?? today
        next.state = next.intervalDays >= masteredThreshold ? .mastered : .learning
        return next
    }
}

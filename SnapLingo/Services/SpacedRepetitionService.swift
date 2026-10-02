//
//  SpacedRepetitionService.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 一个词的复习状态（纯值类型，方便测试）
struct SRSState: Equatable, Sendable {
    var state: WordState
    /// 记忆稳定性：过多少天，还记得的概率会降到 90%。0 表示还没学过
    var stability: Double
    /// 难度 1...10
    var difficulty: Double
    var intervalDays: Int
    var repetitions: Int
    var lapses: Int
    var dueDate: Date
    var lastReviewedAt: Date?

    static func fresh(on date: Date, calendar: Calendar = .current) -> SRSState {
        SRSState(state: .new, stability: 0, difficulty: 0, intervalDays: 0, repetitions: 0, lapses: 0, dueDate: calendar.startOfDay(for: date), lastReviewedAt: nil)
    }
}

/// FSRS-6：估算每个词现在还记得的概率，在快降到 90% 时安排复习
///
/// - 用的是 FSRS-6 的默认参数（从大量真实复习记录里训练出来的）
/// - 按自然日安排：最短明天，最长一年
/// - 3 天以上的间隔会随机前后挪一点，避免同一天学的词以后总挤在同一天
/// - 间隔 ≥ 21 天视为已掌握（仍会按期复习）
/// - 界面上只有“不会 / 会 / 太简单”三个按钮，“太简单”直接不再复习（见 StudySession）；
///   “模糊”只用于回放旧的复习记录
enum SpacedRepetition {
    static let masteredThreshold = 21
    static let maxInterval = 365
    static let desiredRetention = 0.9

    /// FSRS-6 默认参数 w0...w20
    static let w: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796,
        1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ]
    private static let minStability = 0.001
    private static let maxStability = 36500.0

    private static var decay: Double { -w[20] }
    private static var factor: Double { pow(0.9, 1 / decay) - 1 }

    /// 过了 elapsedDays 天，还记得的概率
    static func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + factor * elapsedDays / stability, decay)
    }

    /// - Parameter seed: 决定随机挪几天；同一个词同一次复习传同一个值，按钮上预告的天数才和实际一致
    static func schedule(
        _ current: SRSState,
        rating: ReviewRating,
        on date: Date,
        seed: UInt64 = 0,
        calendar: Calendar = .current
    ) -> SRSState {
        var next = current
        let today = calendar.startOfDay(for: date)
        let grade = Double(rating.grade)

        if current.stability <= 0 {
            next.stability = initialStability(rating.grade)
            next.difficulty = initialDifficulty(grade)
        } else {
            let elapsed = elapsedDays(current, today: today, calendar: calendar)
            if elapsed == 0 {
                next.stability = shortTermStability(current.stability, grade: grade)
            } else {
                let r = retrievability(elapsedDays: Double(elapsed), stability: current.stability)
                next.stability = rating == .again
                    ? forgetStability(current.stability, difficulty: current.difficulty, retrievability: r)
                    : recallStability(current.stability, difficulty: current.difficulty, retrievability: r, rating: rating)
            }
            next.difficulty = nextDifficulty(current.difficulty, grade: grade)
        }
        next.stability = min(max(next.stability, minStability), maxStability)

        if rating == .again {
            if current.state != .new { next.lapses += 1 }
            next.repetitions = 0
        } else {
            next.repetitions = current.repetitions + 1
        }

        next.intervalDays = fuzzed(interval(for: next.stability), seed: seed)
        next.dueDate = calendar.date(byAdding: .day, value: next.intervalDays, to: today) ?? today
        next.lastReviewedAt = date
        next.state = next.intervalDays >= masteredThreshold ? .mastered : .learning
        return next
    }

    /// 同一个词每次复习用不同、但可重复的随机数
    static func seed(for id: UUID, reviewCount: Int) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        }
        hash ^= UInt64(truncatingIfNeeded: reviewCount)
        // splitmix64
        hash = (hash ^ (hash >> 30)) &* 0xbf58476d1ce4e5b9
        hash = (hash ^ (hash >> 27)) &* 0x94d049bb133111eb
        return hash ^ (hash >> 31)
    }

    // MARK: - 公式

    private static func initialStability(_ grade: Int) -> Double {
        max(w[grade - 1], 0.1)
    }

    private static func initialDifficulty(_ grade: Double) -> Double {
        clampDifficulty(rawInitialDifficulty(grade))
    }

    private static func rawInitialDifficulty(_ grade: Double) -> Double {
        w[4] - exp(w[5] * (grade - 1)) + 1
    }

    private static func nextDifficulty(_ difficulty: Double, grade: Double) -> Double {
        let delta = -w[6] * (grade - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        // 慢慢往“太简单”的初始难度回归，避免一个词一直卡在最难
        return clampDifficulty(w[7] * rawInitialDifficulty(4) + (1 - w[7]) * damped)
    }

    private static func recallStability(_ s: Double, difficulty d: Double, retrievability r: Double, rating: ReviewRating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1
        let easyBonus = rating == .easy ? w[16] : 1
        return s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
    }

    private static func forgetStability(_ s: Double, difficulty d: Double, retrievability r: Double) -> Double {
        let forgotten = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
        return min(forgotten, s)
    }

    /// 同一天又复习了一次
    private static func shortTermStability(_ s: Double, grade: Double) -> Double {
        var increase = exp(w[17] * (grade - 3 + w[18])) * pow(s, -w[19])
        if grade >= 3 { increase = max(increase, 1) }
        return s * increase
    }

    private static func clampDifficulty(_ d: Double) -> Double {
        min(max(d, 1), 10)
    }

    private static func elapsedDays(_ state: SRSState, today: Date, calendar: Calendar) -> Int {
        let last = state.lastReviewedAt.map { calendar.startOfDay(for: $0) }
            ?? calendar.date(byAdding: .day, value: -state.intervalDays, to: state.dueDate)
            ?? today
        return max(0, calendar.dateComponents([.day], from: last, to: today).day ?? 0)
    }

    /// 记得的概率正好降到目标值的那天
    private static func interval(for stability: Double) -> Double {
        let days = stability / factor * (pow(desiredRetention, 1 / decay) - 1)
        return min(max(days, 1), Double(maxInterval))
    }

    private static func fuzzed(_ interval: Double, seed: UInt64) -> Int {
        let rounded = Int(interval.rounded())
        guard interval >= 2.5 else { return max(rounded, 1) }
        var delta = 1.0
        for (start, end, factor) in [(2.5, 7.0, 0.15), (7.0, 20.0, 0.1), (20.0, Double.infinity, 0.05)] {
            delta += factor * max(min(interval, end) - start, 0)
        }
        let low = max(2, Int((interval - delta).rounded()))
        let high = min(maxInterval, max(low, Int((interval + delta).rounded())))
        return low + Int(seed % UInt64(high - low + 1))
    }
}

// MARK: - 从旧算法迁移

/// 旧版本用的是 SM-2：按复习记录从头重算一遍每个词的稳定性和难度，学过的东西不会丢
enum SpacedRepetitionMigration {
    /// 每次启动都可以调用：只处理还没有 FSRS 状态的词（包括调试用的示例数据）
    static func run(context: ModelContext) {
        let descriptor = FetchDescriptor<VocabWord>(predicate: #Predicate { $0.stability <= 0 && $0.stateRaw != "new" })
        guard let words = try? context.fetch(descriptor), !words.isEmpty else { return }

        let logs = (try? context.fetch(FetchDescriptor<ReviewLog>(sortBy: [SortDescriptor(\.reviewedAt)]))) ?? []
        let logsByWord = Dictionary(grouping: logs, by: \.wordID)

        for word in words {
            var state: SRSState
            if let history = logsByWord[word.id], let first = history.first {
                state = .fresh(on: first.reviewedAt)
                for (index, log) in history.enumerated() {
                    state = SpacedRepetition.schedule(state, rating: log.rating, on: log.reviewedAt, seed: SpacedRepetition.seed(for: word.id, reviewCount: index))
                }
            } else {
                // 没有复习记录：按当前间隔估一个
                state = word.srs
                state.stability = Double(max(word.intervalDays, 1))
                state.difficulty = 5
            }
            if word.excludedFromReview { state.state = .mastered }
            word.srs = state
        }
        try? context.save()
    }
}

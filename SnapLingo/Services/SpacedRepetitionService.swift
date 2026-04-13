//
//  SpacedRepetitionService.swift
//  SnapLingo
//

import Foundation

struct SM2Result {
    let newEaseFactor: Double
    let newInterval: Int
    let newRepetitions: Int
    let nextReviewDate: Date
}

final class SpacedRepetitionService {

    /// SM-2 算法：根据质量评分计算下次复习安排
    /// - Parameter quality: 0=完全忘记, 3=勉强想起, 4=正确, 5=轻松
    func calculateNextReview(
        quality: Int,
        easeFactor: Double,
        interval: Int,
        repetitions: Int
    ) -> SM2Result {

        let success = quality >= 3

        let newReps: Int
        let newInterval: Int
        let newEF: Double

        if !success {
            // 答错：重置
            newReps = 0
            newInterval = 1
            newEF = max(1.3, easeFactor - 0.2)
        } else {
            // 答对：按 SM-2 公式计算
            newReps = repetitions + 1
            switch repetitions {
            case 0:  newInterval = 1
            case 1:  newInterval = 6
            default: newInterval = min(Int((Double(interval) * easeFactor).rounded()), 180)
            }
            // EF 更新公式
            let delta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
            newEF = max(1.3, easeFactor + delta)
        }

        let nextDate = Calendar.current.date(byAdding: .day, value: newInterval, to: Date()) ?? Date()
        return SM2Result(
            newEaseFactor: newEF,
            newInterval: newInterval,
            newRepetitions: newReps,
            nextReviewDate: nextDate
        )
    }

    /// 筛选今日需要复习的词，按最过期排最前
    func dueWords(from words: [VocabWord]) -> [VocabWord] {
        words
            .filter(\.isDueForReview)
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }
}

//
//  ReviewViewModel.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct ReviewResult {
    let word: String
    let quality: Int
}

@Observable
final class ReviewViewModel {

    // MARK: - 状态

    var queue: [VocabWord] = []
    var currentIndex = 0
    var isShowingAnswer = false
    var sessionResults: [ReviewResult] = []
    var sessionComplete = false

    // MARK: - 依赖

    private let srService = SpacedRepetitionService()

    // MARK: - 计算属性

    var currentWord: VocabWord? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var progress: Double {
        guard !queue.isEmpty else { return 0 }
        return Double(currentIndex) / Double(queue.count)
    }

    var totalCount: Int { queue.count }
    var doneCount: Int { currentIndex }

    // MARK: - 动作

    /// 从所有词中筛出到期词，随机排序
    func load(from words: [VocabWord]) {
        loadExact(words: srService.dueWords(from: words).shuffled())
    }

    /// 直接加载指定词列表（已经过滤好）
    func loadExact(words: [VocabWord]) {
        queue = words
        currentIndex = 0
        isShowingAnswer = false
        sessionResults = []
        sessionComplete = false
    }

    func revealAnswer() {
        isShowingAnswer = true
    }

    /// quality: 0=忘了, 3=难, 4=对, 5=易
    func rate(quality: Int, context: ModelContext) {
        guard let word = currentWord else { return }

        let result = srService.calculateNextReview(
            quality: quality,
            easeFactor: word.easeFactor,
            interval: word.interval,
            repetitions: word.repetitions
        )

        // 写回 SwiftData
        word.easeFactor   = result.newEaseFactor
        word.interval     = result.newInterval
        word.repetitions  = result.newRepetitions
        word.nextReviewDate = result.nextReviewDate
        word.lastReviewedAt = Date()

        // 记录复习历史
        let session = ReviewSession(
            wordID: word.id,
            wordText: word.word,
            quality: quality,
            intervalAfter: result.newInterval
        )
        context.insert(session)

        sessionResults.append(ReviewResult(word: word.word, quality: quality))

        // 下一张
        currentIndex += 1
        isShowingAnswer = false

        if currentIndex >= queue.count {
            sessionComplete = true
        }
    }
}

//
//  ReviewLog.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 评分按钮
enum ReviewRating: Int, Codable, CaseIterable, Identifiable, Sendable {
    case again = 0
    case hard = 3
    case good = 4
    case easy = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .again: "忘了"
        case .hard:  "模糊"
        case .good:  "认识"
        case .easy:  "太简单"
        }
    }

    var symbol: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .hard:  "questionmark"
        case .good:  "checkmark"
        case .easy:  "bolt.fill"
        }
    }

    var isSuccess: Bool { self != .again }
}

/// 每一次评分记录，用于统计、连续天数和今日进度
@Model
final class ReviewLog {
    var id: UUID = UUID()
    /// 对应 VocabWord.id（不做关系，单词删掉后记录仍保留）
    var wordID: UUID = UUID()
    var word: String = ""
    var reviewedAt: Date = Date()
    var ratingRaw: Int = ReviewRating.good.rawValue
    /// 这次是不是第一次学这个词
    var wasNew: Bool = false
    var intervalAfter: Int = 0

    init(wordID: UUID, word: String, rating: ReviewRating, wasNew: Bool, intervalAfter: Int, reviewedAt: Date = Date()) {
        self.id = UUID()
        self.wordID = wordID
        self.word = word
        self.ratingRaw = rating.rawValue
        self.wasNew = wasNew
        self.intervalAfter = intervalAfter
        self.reviewedAt = reviewedAt
    }

    var rating: ReviewRating { ReviewRating(rawValue: ratingRaw) ?? .good }
}

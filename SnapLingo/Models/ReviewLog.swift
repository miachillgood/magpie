//
//  ReviewLog.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 评分。界面上只有“不会 / 会 / 太简单”（见 buttons），“模糊”只出现在旧的复习记录里
enum ReviewRating: Int, Codable, CaseIterable, Identifiable, Sendable {
    case again = 0
    case hard = 3
    case good = 4
    case easy = 5

    var id: Int { rawValue }

    /// 复习时显示的按钮
    static let buttons: [ReviewRating] = [.again, .good, .easy]

    /// FSRS 的评分 1...4
    var grade: Int {
        switch self {
        case .again: 1
        case .hard:  2
        case .good:  3
        case .easy:  4
        }
    }

    var title: String {
        switch self {
        case .again: String(localized: "不会", comment: "Flashcard rating button")
        case .hard:  String(localized: "模糊", comment: "Flashcard rating button")
        case .good:  String(localized: "会", comment: "Flashcard rating button")
        case .easy:  String(localized: "太简单", comment: "Flashcard rating button")
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

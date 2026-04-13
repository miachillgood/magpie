//
//  ReviewSession.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 记录每次单词复习事件，用于统计和调试 SM-2 行为
@Model
final class ReviewSession {
    var id: UUID
    var wordID: UUID            // 关联的 VocabWord.id（不用 SwiftData 关系，避免级联删除影响记录）
    var wordText: String        // 冗余存词汇原文，防止单词被删后丢失记录
    var performedAt: Date
    var quality: Int            // SM-2 质量评分 0-5
    var intervalAfter: Int      // 本次复习后分配的间隔天数

    init(wordID: UUID, wordText: String, quality: Int, intervalAfter: Int) {
        self.id = UUID()
        self.wordID = wordID
        self.wordText = wordText
        self.performedAt = Date()
        self.quality = quality
        self.intervalAfter = intervalAfter
    }
}

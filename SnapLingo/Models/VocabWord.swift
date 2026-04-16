//
//  VocabWord.swift
//  SnapLingo
//

import Foundation
import SwiftData

// MARK: - Scene Tag

enum SceneTag: String, Codable, CaseIterable {
    case restaurant  = "餐厅"
    case supermarket = "超市"
    case medical     = "医疗"
    case legal       = "法律"
    case signage     = "标识"
    case general     = "通用"

    var icon: String {
        switch self {
        case .restaurant:  return "fork.knife"
        case .supermarket: return "cart"
        case .medical:     return "cross.case"
        case .legal:       return "doc.text"
        case .signage:     return "signpost.right"
        case .general:     return "text.bubble"
        }
    }

    var defaultCategory: String {
        switch self {
        case .restaurant:  return "餐厅美食"
        case .supermarket: return "超市购物"
        case .medical:     return "医疗保健"
        case .legal:       return "法律文件"
        case .signage:     return "路牌标识"
        case .general:     return "通用"
        }
    }
}

// MARK: - VocabWord

@Model
final class VocabWord {
    // 基础信息
    var id: UUID
    var word: String
    var normalizedForm: String          // 小写去空格，用于去重查询

    // AI 生成内容
    var chineseExplanation: String
    var exampleSentence: String
    var exampleSentenceChinese: String
    var sceneNote: String               // 场景化补充说明
    var sceneTag: SceneTag

    // 原图缩略图（150x150 JPEG Data，复习时场景回溯用）
    var sourceImageThumbnail: Data?

    // SM-2 间隔重复字段
    var easeFactor: Double              // 难易系数，默认 2.5
    var interval: Int                   // 下次复习间隔（天）
    var repetitions: Int                // 连续答对次数
    var nextReviewDate: Date
    var lastReviewedAt: Date?

    // 元数据
    var addedAt: Date
    var isMastered: Bool                // 用户手动标记为已掌握
    var scanSessionID: UUID = UUID()    // 同一次扫描保存的词共享此 ID，用于词库分组
    var categoryName: String = "通用"   // 用户自定义分类名（中文）

    init(
        word: String,
        chineseExplanation: String,
        exampleSentence: String,
        exampleSentenceChinese: String,
        sceneNote: String = "",
        sceneTag: SceneTag = .general,
        scanSessionID: UUID = UUID(),
        categoryName: String = "通用"
    ) {
        self.id = UUID()
        self.word = word
        self.normalizedForm = word.lowercased().trimmingCharacters(in: .whitespaces)
        self.chineseExplanation = chineseExplanation
        self.exampleSentence = exampleSentence
        self.exampleSentenceChinese = exampleSentenceChinese
        self.sceneNote = sceneNote
        self.sceneTag = sceneTag
        self.scanSessionID = scanSessionID
        self.categoryName = categoryName
        self.easeFactor = 2.5
        self.interval = 1
        self.repetitions = 0
        self.nextReviewDate = Date()
        self.addedAt = Date()
        self.isMastered = false
    }

    /// 是否今天需要复习
    var isDueForReview: Bool {
        !isMastered && nextReviewDate <= Date()
    }
}

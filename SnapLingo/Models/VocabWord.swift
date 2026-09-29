//
//  VocabWord.swift
//  SnapLingo
//

import Foundation
import SwiftData

// MARK: - 学习状态

enum WordState: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 已保存，还没开始学
    case new
    /// 学习中（复习间隔 < 21 天）
    case learning
    /// 已掌握（复习间隔 ≥ 21 天，或手动标记）
    case mastered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new:      "待学"
        case .learning: "学习中"
        case .mastered: "已掌握"
        }
    }

    var symbol: String {
        switch self {
        case .new:      "tray"
        case .learning: "brain.head.profile"
        case .mastered: "checkmark.seal"
        }
    }
}

enum ExplanationStatus: String, Codable, Sendable {
    case pending
    case ready
    case failed
}

// MARK: - VocabWord（唯一的单词数据源，SRS 状态也在这里）

@Model
final class VocabWord {
    var id: UUID = UUID()
    /// 展示用词形（通常是原形）
    var word: String = ""
    /// 去重 key
    var normalizedForm: String = ""
    var partOfSpeech: String = ""
    /// 1...6 对应 A1...C2；0 表示未知
    var cefrRaw: Int = 0
    var phonetic: String = ""
    /// 简短中文释义（识别阶段就有）
    var gloss: String = ""

    // AI 解释（保存后批量生成）
    var explanation: String = ""
    var exampleSentence: String = ""
    var exampleTranslation: String = ""
    var sceneNote: String = ""
    var explanationStatusRaw: String = ExplanationStatus.pending.rawValue
    /// 单词在照片里出现的那一行
    var contextSnippet: String = ""

    // SRS
    var stateRaw: String = WordState.new.rawValue
    /// 手动标记“已掌握，不再复习”
    var excludedFromReview: Bool = false
    var easeFactor: Double = 2.5
    var intervalDays: Int = 0
    var repetitions: Int = 0
    var lapses: Int = 0
    /// 到期日（当天 0 点）
    var dueDate: Date = Date()
    var lastReviewedAt: Date?
    var introducedAt: Date?

    var addedAt: Date = Date()

    var scans: [Scan] = []

    init(
        word: String,
        partOfSpeech: String = "",
        cefr: CEFRLevel? = nil,
        gloss: String = "",
        contextSnippet: String = "",
        addedAt: Date = Date()
    ) {
        self.id = UUID()
        self.word = word
        self.normalizedForm = word.normalizedWordKey
        self.partOfSpeech = partOfSpeech
        self.cefrRaw = cefr?.rawValue ?? 0
        self.gloss = gloss
        self.contextSnippet = contextSnippet
        self.addedAt = addedAt
        self.dueDate = Calendar.current.startOfDay(for: addedAt)
    }

    // MARK: - 计算属性

    var state: WordState {
        get { WordState(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue }
    }

    var explanationStatus: ExplanationStatus {
        get { ExplanationStatus(rawValue: explanationStatusRaw) ?? .pending }
        set { explanationStatusRaw = newValue.rawValue }
    }

    var cefr: CEFRLevel? { CEFRLevel(rawValue: cefrRaw) }

    /// 释义：优先完整解释，其次识别时的简短释义
    var meaning: String {
        explanation.isEmpty ? gloss : explanation
    }

    /// 最近一次出现的场景（有照片的优先）
    var latestScan: Scan? {
        scans.max { $0.createdAt < $1.createdAt }
    }

    var srs: SRSState {
        get {
            SRSState(
                state: state,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                lapses: lapses,
                dueDate: dueDate
            )
        }
        set {
            state = newValue.state
            easeFactor = newValue.easeFactor
            intervalDays = newValue.intervalDays
            repetitions = newValue.repetitions
            lapses = newValue.lapses
            dueDate = newValue.dueDate
        }
    }

    func applyExplanation(_ exp: WordExplanation) {
        explanation = exp.explanation
        exampleSentence = exp.exampleSentence
        exampleTranslation = exp.exampleTranslation
        sceneNote = exp.sceneNote
        if !exp.phonetic.isEmpty { phonetic = exp.phonetic }
        explanationStatus = .ready
    }
}

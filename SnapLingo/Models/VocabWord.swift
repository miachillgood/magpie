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
        case .new:      String(localized: "待学", comment: "Word learning state")
        case .learning: String(localized: "学习中", comment: "Word learning state")
        case .mastered: String(localized: "已掌握", comment: "Word learning state")
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
    /// 旧算法（SM-2）的难度系数，现在不用了，留着是为了不改数据库结构
    var easeFactor: Double = 2.5
    /// FSRS 记忆稳定性（天）；0 表示还没按 FSRS 算过
    var stability: Double = 0
    /// FSRS 难度 1...10
    var difficulty: Double = 0
    var intervalDays: Int = 0
    var repetitions: Int = 0
    var lapses: Int = 0
    /// 到期日（当天 0 点）
    var dueDate: Date = Date()
    var lastReviewedAt: Date?
    var introducedAt: Date?
    /// 最近一次点「不会」的时间；之后再点「会 / 太简单」就清掉。不为空 = 在「错词重练」里
    var mistakeAt: Date?

    var addedAt: Date = Date()

    var scans: [Scan] = []
    /// 用户自己建的文件夹（多对多，见 WordFolder.words）
    var folders: [WordFolder] = []
    /// 用户手动改过的分类（SceneType 的 raw value）；空表示跟着照片走
    var categoryOverrideRaw: String = ""

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
                stability: stability,
                difficulty: difficulty,
                intervalDays: intervalDays,
                repetitions: repetitions,
                lapses: lapses,
                dueDate: dueDate,
                lastReviewedAt: lastReviewedAt
            )
        }
        set {
            state = newValue.state
            stability = newValue.stability
            difficulty = newValue.difficulty
            intervalDays = newValue.intervalDays
            repetitions = newValue.repetitions
            lapses = newValue.lapses
            dueDate = newValue.dueDate
            lastReviewedAt = newValue.lastReviewedAt
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

//
//  LevelService.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 候选词在选词页里的分组
enum CandidateGroup: String, CaseIterable, Identifiable, Sendable {
    /// 在「我的等级 ~ 等级 +1」之间：最值得学
    case recommended
    /// 更难的词
    case advanced
    /// 低于水平或之前表示过认识
    case known
    /// 已经在词库里
    case saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: "推荐给你"
        case .advanced:    "进阶挑战"
        case .known:       "可能已经认识"
        case .saved:       "已在词库"
        }
    }

    var symbol: String {
        switch self {
        case .recommended: "sparkles"
        case .advanced:    "flame"
        case .known:       "checkmark.circle"
        case .saved:       "tray.full"
        }
    }
}

struct ClassifiedCandidate: Identifiable, Hashable, Sendable {
    var candidate: WordCandidate
    var group: CandidateGroup
    var preselected: Bool
    var id: String { candidate.key }
}

/// 水平相关的规则：推荐分组、分数自适应、熟悉度记录
enum LevelService {
    static let maxPreselected = 8
    static let knownConfidence = 0.7
    static let unknownConfidence = 0.3

    // MARK: - 推荐（i+1）

    static func classify(
        _ candidates: [WordCandidate],
        level: CEFRLevel,
        familiarity: [String: Double],
        savedKeys: Set<String>
    ) -> [ClassifiedCandidate] {
        var preselectedCount = 0
        return candidates.map { candidate in
            let group = group(for: candidate, level: level, familiarity: familiarity, savedKeys: savedKeys)
            var preselected = false
            if group == .recommended && preselectedCount < maxPreselected {
                preselected = true
                preselectedCount += 1
            }
            if candidate.pickedFromPhoto && group != .saved {
                preselected = true
            }
            return ClassifiedCandidate(candidate: candidate, group: group, preselected: preselected)
        }
    }

    static func group(
        for candidate: WordCandidate,
        level: CEFRLevel,
        familiarity: [String: Double],
        savedKeys: Set<String>
    ) -> CandidateGroup {
        if savedKeys.contains(candidate.key) { return .saved }
        if candidate.pickedFromPhoto { return .recommended }
        if let confidence = familiarity[candidate.key] {
            if confidence >= knownConfidence { return .known }
            if confidence <= unknownConfidence { return .recommended }
        }
        let wordLevel = candidate.cefr ?? level
        if wordLevel < level { return .known }
        if wordLevel.rawValue <= level.rawValue + 1 { return .recommended }
        return .advanced
    }

    // MARK: - 分数自适应

    static func clamp(_ score: Double) -> Double { min(max(score, 0), 100) }

    /// 保存选词时的反馈：取消推荐词说明偏简单，勾选“可能认识”的词说明偏难
    static func selectionDelta(classified: [ClassifiedCandidate], selectedKeys: Set<String>) -> Double {
        var delta = 0.0
        for item in classified where !item.candidate.pickedFromPhoto {
            let selected = selectedKeys.contains(item.id)
            switch item.group {
            case .recommended where !selected: delta += 0.6
            case .known where selected:        delta -= 0.6
            default: break
            }
        }
        return min(max(delta, -3), 3)
    }

    /// 第一次学一个词时的反馈
    static func firstSightDelta(rating: ReviewRating, wordLevel: CEFRLevel?, userLevel: CEFRLevel) -> Double {
        guard let wordLevel else { return 0 }
        switch rating {
        case .easy where wordLevel >= userLevel:  return 0.5
        case .again where wordLevel <= userLevel: return -0.5
        default: return 0
        }
    }

    static func confidence(for rating: ReviewRating) -> Double {
        switch rating {
        case .again: 0.2
        case .hard:  0.45
        case .good:  0.75
        case .easy:  0.9
        }
    }

    // MARK: - 熟悉度存取

    static func familiarityMap(in context: ModelContext) -> [String: Double] {
        let rows = (try? context.fetch(FetchDescriptor<WordFamiliarity>())) ?? []
        return Dictionary(rows.map { ($0.normalizedForm, $0.confidence) }, uniquingKeysWith: { _, latest in latest })
    }

    static func recordFamiliarity(
        key: String,
        confidence: Double,
        source: FamiliaritySource,
        in context: ModelContext
    ) {
        let descriptor = FetchDescriptor<WordFamiliarity>(predicate: #Predicate { $0.normalizedForm == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.record(confidence: confidence, source: source)
        } else {
            context.insert(WordFamiliarity(normalizedForm: key, confidence: confidence, source: source))
        }
    }

    /// 选词保存时，把“认识 / 不认识”的信号写进熟悉度
    static func recordSelection(
        classified: [ClassifiedCandidate],
        selectedKeys: Set<String>,
        in context: ModelContext
    ) {
        for item in classified where item.group != .saved && !item.candidate.pickedFromPhoto {
            let selected = selectedKeys.contains(item.id)
            switch (item.group, selected) {
            case (.recommended, false):
                recordFamiliarity(key: item.id, confidence: 0.85, source: .scanSelection, in: context)
            case (.known, true):
                recordFamiliarity(key: item.id, confidence: 0.2, source: .scanSelection, in: context)
            default:
                break
            }
        }
    }
}

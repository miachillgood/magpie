//
//  WordFamiliarity.swift
//  SnapLingo
//

import Foundation
import SwiftData

enum FamiliaritySource: String, Codable, CaseIterable, Sendable {
    case assessment
    case scanSelection
    case review
    case mastery
}

/// 用户对某个词的熟悉程度（包括没有保存的词），用来决定下次是否还推荐它
@Model
final class WordFamiliarity {
    var normalizedForm: String = ""
    /// 0...1，越高越熟
    var confidence: Double = 0.5
    var evidenceCount: Int = 1
    var lastSourceRaw: String = FamiliaritySource.scanSelection.rawValue
    var updatedAt: Date = Date()

    init(normalizedForm: String, confidence: Double, source: FamiliaritySource, updatedAt: Date = Date()) {
        self.normalizedForm = normalizedForm
        self.confidence = confidence
        self.evidenceCount = 1
        self.lastSourceRaw = source.rawValue
        self.updatedAt = updatedAt
    }

    var lastSource: FamiliaritySource { FamiliaritySource(rawValue: lastSourceRaw) ?? .scanSelection }

    /// 用滑动平均合并一条新证据
    func record(confidence observed: Double, source: FamiliaritySource, at date: Date = Date()) {
        let weight = 1.0 / Double(min(evidenceCount + 1, 4))
        confidence = min(max(confidence * (1 - weight) + observed * weight, 0), 1)
        evidenceCount += 1
        lastSourceRaw = source.rawValue
        updatedAt = date
    }
}

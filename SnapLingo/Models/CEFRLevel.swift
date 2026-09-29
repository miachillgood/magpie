//
//  CEFRLevel.swift
//  SnapLingo
//

import Foundation

/// 欧洲语言共同参考框架等级，用来描述单词难度和用户水平
enum CEFRLevel: Int, Codable, CaseIterable, Comparable, Identifiable, Sendable {
    case a1 = 1, a2, b1, b2, c1, c2

    var id: Int { rawValue }

    var code: String {
        switch self {
        case .a1: "A1"
        case .a2: "A2"
        case .b1: "B1"
        case .b2: "B2"
        case .c1: "C1"
        case .c2: "C2"
        }
    }

    var displayName: String {
        switch self {
        case .a1: "入门"
        case .a2: "基础"
        case .b1: "进阶"
        case .b2: "中高级"
        case .c1: "高级"
        case .c2: "精通"
        }
    }

    var summary: String {
        switch self {
        case .a1: "能看懂最常见的标识和价格"
        case .a2: "能应付购物、点餐等日常场景"
        case .b1: "能读懂大部分生活通知和说明"
        case .b2: "能处理租房、银行等正式文件"
        case .c1: "能读懂合同条款和专业材料"
        case .c2: "几乎和母语者一样"
        }
    }

    init?(code: String) {
        let upper = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard let match = CEFRLevel.allCases.first(where: { $0.code == upper }) else { return nil }
        self = match
    }

    static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var next: CEFRLevel? { CEFRLevel(rawValue: rawValue + 1) }

    // MARK: - 分数映射（0...100，每级约 16.7 分）

    static let scorePerLevel = 100.0 / Double(allCases.count)

    static func from(score: Double) -> CEFRLevel {
        let clamped = min(max(score, 0), 99.999)
        return CEFRLevel(rawValue: Int(clamped / scorePerLevel) + 1) ?? .b1
    }

    /// 当前等级内的进度（0...1），用于展示“离下一级还有多远”
    static func progressWithinLevel(score: Double) -> Double {
        let clamped = min(max(score, 0), 100)
        let level = from(score: clamped)
        let base = Double(level.rawValue - 1) * scorePerLevel
        return min(max((clamped - base) / scorePerLevel, 0), 1)
    }

    var midScore: Double { (Double(rawValue) - 0.5) * CEFRLevel.scorePerLevel }
}

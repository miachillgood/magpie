//
//  AppSettings.swift
//  SnapLingo
//

import Foundation
import SwiftData

// MARK: - User Level

enum UserLevel: String, Codable, CaseIterable {
    case unknown        // 尚未评估
    case beginner       // 初级：第一次拍照选词率 > 70%
    case intermediate   // 中级：30%-70%
    case advanced       // 高级：< 30%

    var displayName: String {
        switch self {
        case .unknown:      return "未知"
        case .beginner:     return "初级"
        case .intermediate: return "中级"
        case .advanced:     return "高级"
        }
    }
}

// MARK: - AppSettings（单行模型，始终只有一条记录）

@Model
final class AppSettings {
    /// Claude API Key 实际存在 Keychain；这里仅做"是否已设置"的标记
    var apiKeyConfigured: Bool
    /// 用户英语水平（由首次选词行为推断，之后持续校准）
    var estimatedUserLevel: UserLevel
    /// 累计学习词汇数
    var totalWordsLearned: Int
    /// 是否完成新手引导
    var onboardingCompleted: Bool
    /// 每日复习目标
    var dailyReviewGoal: Int

    init() {
        self.apiKeyConfigured = false
        self.estimatedUserLevel = .unknown
        self.totalWordsLearned = 0
        self.onboardingCompleted = false
        self.dailyReviewGoal = 20
    }
}

//
//  UserSettings.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 每日节奏
enum StudyPace: Int, CaseIterable, Identifiable, Sendable {
    case relaxed = 5
    case standard = 10
    case intense = 20

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .relaxed:  "轻松"
        case .standard: "标准"
        case .intense:  "进取"
        }
    }

    var detail: String {
        switch self {
        case .relaxed:  "每天 5 个新词，约 5 分钟"
        case .standard: "每天 10 个新词，约 10 分钟"
        case .intense:  "每天 20 个新词，约 20 分钟"
        }
    }

    var symbol: String {
        switch self {
        case .relaxed:  "tortoise"
        case .standard: "figure.walk"
        case .intense:  "hare"
        }
    }
}

/// 发音口音
enum SpeechAccent: String, CaseIterable, Identifiable, Sendable {
    case newZealand = "en-NZ"
    case australia = "en-AU"
    case britain = "en-GB"
    case america = "en-US"
    case canada = "en-CA"
    case ireland = "en-IE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newZealand: "新西兰"
        case .australia:  "澳大利亚"
        case .britain:    "英国"
        case .america:    "美国"
        case .canada:     "加拿大"
        case .ireland:    "爱尔兰"
        }
    }

    /// 根据当前地区选择默认口音
    static var regionDefault: SpeechAccent {
        switch Locale.current.region?.identifier {
        case "NZ": .newZealand
        case "AU": .australia
        case "GB": .britain
        case "CA": .canada
        case "IE": .ireland
        default:   .america
        }
    }
}

/// 全局设置（单行）
@Model
final class UserSettings {
    /// 0...100，映射到 CEFR 等级
    var levelScore: Double = CEFRLevel.b1.midScore
    var assessmentCompleted: Bool = false
    var onboardingCompleted: Bool = false
    var newWordsPerDay: Int = StudyPace.standard.rawValue
    var maxReviewsPerDay: Int = 100
    var reminderEnabled: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0
    var accentRaw: String = SpeechAccent.regionDefault.rawValue
    var createdAt: Date = Date()

    init() {}

    var level: CEFRLevel { CEFRLevel.from(score: levelScore) }

    var accent: SpeechAccent {
        get { SpeechAccent(rawValue: accentRaw) ?? .regionDefault }
        set { accentRaw = newValue.rawValue }
    }

    var pace: StudyPace? { StudyPace(rawValue: newWordsPerDay) }

    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = parts.hour ?? 20
            reminderMinute = parts.minute ?? 0
        }
    }
}

extension UserSettings {
    /// 取出唯一的设置行，没有就创建
    static func current(in context: ModelContext) -> UserSettings {
        if let existing = try? context.fetch(FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}

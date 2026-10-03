//
//  UserSettings.swift
//  SnapLingo
//

import Foundation
import SwiftData

/// 每天最多学几个新词。引导里不问，默认标准档；第一次真的有新词排队时在结算页问一次
enum StudyPace: Int, CaseIterable, Identifiable, Sendable {
    case relaxed = 5
    case standard = 10
    case intense = 20

    var id: Int { rawValue }

    /// 「我的」页、复习页的目标面板、结算页可选的每天新词数
    static let dailyOptions = [5, 10, 15, 20, 30]

    /// 在 dailyOptions 里往上（step > 0）或往下挪 step 档，到两头就停住。
    /// 不在列表里的值（比如调试时设的 2）：往上取比它大的第一档，往下取比它小的第一档，不动就取最近的一档
    static func adjusted(_ current: Int, by step: Int) -> Int {
        let options = dailyOptions
        let start: Int
        if let exact = options.firstIndex(of: current) {
            start = exact + step
        } else if step > 0 {
            start = (options.firstIndex { $0 > current } ?? options.count - 1) + step - 1
        } else if step < 0 {
            start = (options.lastIndex { $0 < current } ?? 0) + step + 1
        } else {
            start = options.indices.min { abs(options[$0] - current) < abs(options[$1] - current) } ?? 0
        }
        return options[min(max(start, 0), options.count - 1)]
    }

    /// 结算页问「节奏合适吗？」：今天的计划做完了、还有新词在排队（上限真的挡住了词），而且以前没问过
    static func shouldAsk(plan: DailyPlan, backlog: Int, asked: Bool) -> Bool {
        !asked && !plan.hasWork && backlog > 0
    }

    /// 每个新词连同当天的复习大约 1 分钟
    static func minutes(forNewWords count: Int) -> Int { count }
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

    /// 国家名，跟随界面语言（新西兰 / New Zealand / ニュージーランド）
    var title: String {
        let region = String(rawValue.suffix(2))
        return Locale.current.localizedString(forRegionCode: region) ?? region
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
    /// 结算页的「节奏合适吗？」问过了没有
    /// 以前结算页会问一次「节奏合适吗？」，现在不问了；留着字段是为了不改数据库结构
    var paceCheckDone: Bool = false
    var maxReviewsPerDay: Int = 100
    var reminderEnabled: Bool = false
    var reminderHour: Int = 20
    var reminderMinute: Int = 0
    var accentRaw: String = SpeechAccent.regionDefault.rawValue
    var createdAt: Date = Date()

    // 个人资料（只存在这台手机上）
    var nickname: String = ""
    @Attribute(.externalStorage) var avatarData: Data?
    /// 通过 Apple 登录后的用户标识；为空表示没登录
    var appleUserID: String = ""
    var appleEmail: String = ""

    /// 母语：释义、例句翻译用什么语言生成
    var nativeLanguageRaw: String = NativeLanguage().rawValue

    init() {}

    var nativeLanguage: NativeLanguage {
        get { NativeLanguage(rawValue: nativeLanguageRaw) ?? NativeLanguage() }
        set { nativeLanguageRaw = newValue.rawValue }
    }

    var isSignedIn: Bool { !appleUserID.isEmpty }

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

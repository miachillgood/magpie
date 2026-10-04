//
//  NativeLanguage.swift
//  SnapLingo
//
//  用户的母语：决定单词释义、例句翻译、场景标题用什么语言生成。
//  和界面语言分开——界面跟随 iOS；两者不一样时会问要不要把界面也换过去（见 InterfaceLanguage）。
//

import Foundation

nonisolated enum NativeLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case portuguese = "pt-BR"
    case english = "en"

    var id: String { rawValue }

    /// 用这种语言自己的写法显示，任何界面语言下都一样
    var endonym: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .portuguese: "Português (Brasil)"
        case .english: "English"
        }
    }

    /// 写进提示词里的英文名
    var promptName: String {
        switch self {
        case .simplifiedChinese: "Simplified Chinese"
        case .traditionalChinese: "Traditional Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .spanish: "Spanish"
        case .portuguese: "Brazilian Portuguese"
        case .english: "simple, plain English"
        }
    }

    /// 中日韩用字符计数，其它语言用单词计数
    var usesCharacterCount: Bool {
        switch self {
        case .simplifiedChinese, .traditionalChinese, .japanese, .korean: true
        case .spanish, .portuguese, .english: false
        }
    }

    /// 给提示词用的长度要求
    func lengthLimit(characters: Int, words: Int) -> String {
        usesCharacterCount ? "at most \(characters) characters" : "at most \(words) words"
    }

    /// 按系统首选语言匹配；都不支持时用英文
    init(preferredLanguages: [String] = Locale.preferredLanguages) {
        for identifier in preferredLanguages {
            if let match = NativeLanguage.match(identifier) {
                self = match
                return
            }
        }
        self = .english
    }

    private static func match(_ identifier: String) -> NativeLanguage? {
        let locale = Locale(identifier: identifier)
        let language = locale.language.languageCode?.identifier ?? identifier
        switch language {
        case "zh":
            // 写明了文字就按文字；没写时 zh-TW / zh-HK / zh-MO 算繁体
            switch locale.language.script?.identifier {
            case "Hant": return .traditionalChinese
            case "Hans": return .simplifiedChinese
            default: return ["TW", "HK", "MO"].contains(locale.region?.identifier ?? "") ? .traditionalChinese : .simplifiedChinese
            }
        case "ja": return .japanese
        case "ko": return .korean
        case "es": return .spanish
        case "pt": return .portuguese
        case "en": return .english
        default: return nil
        }
    }
}

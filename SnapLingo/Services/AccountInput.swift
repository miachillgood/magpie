//
//  AccountInput.swift
//  SnapLingo
//
//  登录页的输入规则：手机号拼成国际格式、打码显示，邮箱和验证码的校验。纯逻辑，方便测试。
//

import Foundation

/// 手机号登录支持的地区（要和短信服务后台允许的国家一致）
nonisolated struct PhoneRegion: Identifiable, Hashable, Sendable {
    /// 地区代码，如 NZ
    let code: String
    /// 国际区号，如 64
    let dialCode: String

    var id: String { code }

    static let supported: [PhoneRegion] = [
        PhoneRegion(code: "NZ", dialCode: "64"),
        PhoneRegion(code: "AU", dialCode: "61"),
        PhoneRegion(code: "GB", dialCode: "44"),
        PhoneRegion(code: "US", dialCode: "1"),
        PhoneRegion(code: "CA", dialCode: "1"),
        PhoneRegion(code: "IE", dialCode: "353")
    ]

    /// 按手机的地区设置选默认，不在支持列表里就用新西兰
    static func defaultRegion(for regionCode: String?) -> PhoneRegion {
        supported.first { $0.code == regionCode?.uppercased() } ?? supported[0]
    }

    /// 地区名跟随界面语言：新西兰 / New Zealand / ニュージーランド
    func name(locale: Locale = .current) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }
}

nonisolated enum AccountInput {
    static let codeLength = 6

    static func digits(_ text: String) -> String {
        String(text.filter(\.isASCII).filter(\.isNumber))
    }

    /// 本地号码拼成国际格式：021 234 5678 → +64212345678。
    /// 开头的 0 是国内拨号用的，去掉；用户连区号一起输入（64 21…）也认。长度不对返回 nil
    static func e164(national: String, region: PhoneRegion) -> String? {
        var number = digits(national)
        if number.count > 10, number.hasPrefix(region.dialCode) {
            number.removeFirst(region.dialCode.count)
        }
        while number.hasPrefix("0") { number.removeFirst() }
        guard (6...12).contains(number.count) else { return nil }
        return "+" + region.dialCode + number
    }

    /// 打码显示：+64 21 •••• 678
    static func maskedPhone(_ e164: String, region: PhoneRegion) -> String {
        let national = String(digits(e164).dropFirst(region.dialCode.count))
        guard national.count > 5 else { return "+\(region.dialCode) \(national)" }
        return "+\(region.dialCode) \(national.prefix(2)) •••• \(national.suffix(3))"
    }

    static func isValidEmail(_ text: String) -> Bool {
        let email = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s.]{2,}/) != nil
    }

    static func normalizedEmail(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 验证码输入框：只留数字，最多 6 位（从短信里自动填入时可能带空格或别的字）
    static func sanitizedCode(_ text: String) -> String {
        String(digits(text).prefix(codeLength))
    }
}

//
//  Theme.swift
//  SnapLingo
//
//  设计 token：暖白纸张底 + 墨黑按钮 + 珊瑚橙点缀 + 每个场景一种柔和的马卡龙色。
//  英文单词用衬线体（像词典），中文标题用粗黑体。
//

import SwiftUI
import UIKit

extension Color {
    /// 浅色 / 深色两套取值
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum Theme {
    /// 品牌色：珊瑚橙（AccentColor，含深色模式）
    static let brand = Color("AccentColor")
    static let brandSoft = Color(light: UIColor(hex: 0xFFE4D6), dark: UIColor(hex: 0x3D2419))

    /// 墨色：主要文字和主按钮
    static let ink = Color(light: UIColor(hex: 0x1C1B20), dark: UIColor(hex: 0xF6F2EA))
    /// 墨色按钮上的文字
    static let onInk = Color(light: .white, dark: UIColor(hex: 0x1C1B20))

    /// 纸张底色
    static let paper = Color(light: UIColor(hex: 0xF7F3EC), dark: UIColor(hex: 0x111013))
    /// 卡片
    static let card = Color(light: .white, dark: UIColor(hex: 0x1E1D22))
    /// 卡片里的小块
    static let insetFill = Color(light: UIColor(hex: 0xF3EFE8), dark: UIColor(hex: 0x2A2930))
    static let hairline = Color(light: UIColor(hex: 0x1C1B20, alpha: 0.08), dark: UIColor(white: 1, alpha: 0.1))
    static let dot = Color(light: UIColor(hex: 0x1C1B20, alpha: 0.07), dark: UIColor(white: 1, alpha: 0.06))

    /// 今日计划：新词（品牌色）/ 复习（葡萄紫）
    static let newWords = Color("AccentColor")
    static let reviews = Color(light: UIColor(hex: 0x6B5CF0), dark: UIColor(hex: 0x9A8FFF))

    // 语义色
    static let success = Color(light: UIColor(hex: 0x1FA463), dark: UIColor(hex: 0x3CCB82))
    static let danger = Color.red

    // 兼容旧名字
    static var pageBackground: Color { paper }
    static var cardBackground: Color { card }

    // MARK: 首页（照片墙）

    /// 奶油色底
    static let cream = Color(light: UIColor(hex: 0xFAF6EE), dark: UIColor(hex: 0x14120F))
    /// 下方的白色底板
    static let sheet = Color(light: .white, dark: UIColor(hex: 0x1E1C19))
    /// 墨色（首页用，偏暖）
    static let homeInk = Color(light: UIColor(hex: 0x1F1A17), dark: UIColor(hex: 0xF6F1EA))
    static let homeMuted = Color(light: UIColor(hex: 0x8E857D), dark: UIColor(hex: 0x9C948B))
    /// 荧光笔黄：数字高亮、New! 标签
    static let marker = Color(light: UIColor(hex: 0xFFE27A), dark: UIColor(hex: 0x6B5418))
    /// 地点胶囊
    static let placeChip = Color(light: UIColor(hex: 0xCFE2F7), dark: UIColor(hex: 0x1F3347))
    /// 快门外圈
    static let shutterRing = Color(hex: 0xFFD84A)
    /// 连续天数胶囊
    static let streakFill = Color(light: UIColor(hex: 0xFFEFB8), dark: UIColor(hex: 0x3A3217))
    /// 复习页主题色下面过渡到的浅灰
    static let mist = Color(light: UIColor(hex: 0xF1F1EF), dark: UIColor(hex: 0x121212))
    /// 日期圆点：拍过东西的日子（按词数调深浅）
    static let dayDot = Color(light: UIColor(hex: 0x6E97D6), dark: UIColor(hex: 0x8FB3EC))
}

// MARK: - 马卡龙色

enum Pastel {
    static let peach = Color(light: UIColor(hex: 0xFFE3D3), dark: UIColor(hex: 0x3A2A22))
    static let mint = Color(light: UIColor(hex: 0xD9F2E1), dark: UIColor(hex: 0x1D3325))
    static let pink = Color(light: UIColor(hex: 0xFCE0EC), dark: UIColor(hex: 0x3A2231))
    static let lavender = Color(light: UIColor(hex: 0xE7E2FB), dark: UIColor(hex: 0x2A2641))
    static let sky = Color(light: UIColor(hex: 0xDCEBFB), dark: UIColor(hex: 0x1E2C3D))
    static let aqua = Color(light: UIColor(hex: 0xD6F1F0), dark: UIColor(hex: 0x1A3232))
    static let butter = Color(light: UIColor(hex: 0xFFF0C2), dark: UIColor(hex: 0x3A331B))
    static let sage = Color(light: UIColor(hex: 0xE3EED6), dark: UIColor(hex: 0x272F21))
    static let mist = Color(light: UIColor(hex: 0xE4E8EF), dark: UIColor(hex: 0x262A31))
    static let sand = Color(light: UIColor(hex: 0xEFE8DC), dark: UIColor(hex: 0x2E2B25))
}

extension SceneType {
    var emoji: String {
        switch self {
        case .restaurant:  "🍽️"
        case .supermarket: "🛒"
        case .shopping:    "🛍️"
        case .housing:     "🏠"
        case .campus:      "🎓"
        case .medical:     "💊"
        case .transport:   "🚌"
        case .bank:        "🏦"
        case .legal:       "📄"
        case .signage:     "🪧"
        case .general:     "✨"
        }
    }

    var pastel: Color {
        switch self {
        case .restaurant:  Pastel.peach
        case .supermarket: Pastel.mint
        case .shopping:    Pastel.pink
        case .housing:     Pastel.lavender
        case .campus:      Pastel.sky
        case .medical:     Pastel.aqua
        case .transport:   Pastel.butter
        case .bank:        Pastel.sage
        case .legal:       Pastel.mist
        case .signage:     Pastel.butter
        case .general:     Pastel.sand
        }
    }
}

extension ReviewRating {
    var tint: Color {
        switch self {
        case .again: Color(light: UIColor(hex: 0xE5484D), dark: UIColor(hex: 0xFF6369))
        case .hard:  Color(light: UIColor(hex: 0xE38A00), dark: UIColor(hex: 0xFFB224))
        case .good:  Theme.success
        case .easy:  Color(light: UIColor(hex: 0x0E9AB5), dark: UIColor(hex: 0x3DD6F0))
        }
    }

    var pastel: Color {
        switch self {
        case .again: Pastel.pink
        case .hard:  Pastel.butter
        case .good:  Pastel.mint
        case .easy:  Pastel.sky
        }
    }

    var emoji: String {
        switch self {
        case .again: "😵‍💫"
        case .hard:  "🤔"
        case .good:  "😊"
        case .easy:  "😎"
        }
    }
}

extension WordState {
    var tint: Color {
        switch self {
        case .new:      .secondary
        case .learning: Theme.reviews
        case .mastered: Theme.success
        }
    }

    var emoji: String {
        switch self {
        case .new:      "📥"
        case .learning: "🧠"
        case .mastered: "🏅"
        }
    }
}

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

enum Radius {
    static let small: CGFloat = 14
    static let card: CGFloat = 24
    static let hero: CGFloat = 32
}

// MARK: - 字体

enum Typography {
    /// 导航栏标题用粗体
    static func configureNavigationBar() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: font(.largeTitle, weight: .heavy)]
        appearance.titleTextAttributes = [.font: font(.headline, weight: .bold)]
    }

    private static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        return UIFont.systemFont(ofSize: base.pointSize, weight: weight)
    }
}

extension Font {
    /// 页面大标题（中文粗黑）
    static let display = Font.system(size: 34, weight: .heavy)
    static let displaySmall = Font.system(.title2, weight: .heavy)
    /// 英文单词：衬线体，像词典
    static let wordHero = Font.system(size: 44, weight: .bold, design: .serif)
    static let wordTitle = Font.system(.title, design: .serif, weight: .bold)
    static let wordBody = Font.system(.title3, design: .serif, weight: .semibold)
    static func word(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// 大数字
    static let statNumber = Font.system(.title, design: .rounded, weight: .heavy)

    /// 字标和大数字：Bricolage Grotesque（没打包时退回系统粗体）
    static func brand(_ size: CGFloat) -> Font {
        BundledFont.bricolage.font(size: size) ?? .system(size: size, weight: .heavy)
    }

    /// 手写标签：Caveat（没打包时退回系统自带的手写体）
    static func handwriting(_ size: CGFloat) -> Font {
        BundledFont.caveat.font(size: size) ?? .custom("BradleyHandITCTT-Bold", size: size * 0.86)
    }
}

/// 打包进 App 的开源字体（OFL）。字体文件放进项目并在 Info.plist 的 UIAppFonts 里登记后自动生效
enum BundledFont: String {
    case bricolage = "BricolageGrotesque-ExtraBold"
    case caveat = "Caveat-Bold"

    var isAvailable: Bool { UIFont(name: rawValue, size: 12) != nil }

    func font(size: CGFloat) -> Font? {
        isAvailable ? .custom(rawValue, fixedSize: size) : nil
    }
}

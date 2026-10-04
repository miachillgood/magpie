//
//  Theme.swift
//  SnapLingo
//
//  设计 token：阿迪达斯复古色系——奶油白底、墨蓝按钮、焦橙点缀，每个场景一种调淡的复古色。
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

/// 阿迪达斯复古色系：奶油白底 + 墨蓝文字和按钮 + 焦橙点缀，芥末黄做高亮，
/// 场景和小卡片用学院绿、灰蓝、灰粉、鞋底胶棕这些颜色调淡后的底色。
/// 原色：烟草棕 9A6846 · 芥末黄 D5A536 · 学院绿 315A45 · 复古海军蓝 263A50 · 灰蓝 7896A3 · 砖红 A84E3D ·
///      酒红 713D43 · 灰粉 C58F8A · 焦橙 C16D3D · 奶油白 EEE7D8 · 鞋底胶棕 B88958 · 鼠尾草绿 87947B
enum Theme {
    /// 品牌色：焦橙（AccentColor，含深色模式）
    static let brand = Color("AccentColor")
    static let brandSoft = Color(light: UIColor(hex: 0xF3E2D8), dark: UIColor(hex: 0x4C3121))

    /// 墨色：主要文字和主按钮（压暗的海军蓝）
    static let ink = Color(light: UIColor(hex: 0x1B2A3A), dark: UIColor(hex: 0xEEE7D8))
    /// 墨色按钮上的文字
    static let onInk = Color(light: UIColor(hex: 0xF7F2E8), dark: UIColor(hex: 0x1B2A3A))

    /// 纸张底色
    static let paper = Color(light: UIColor(hex: 0xF6F1E7), dark: UIColor(hex: 0x13110E))
    /// 卡片
    static let card = Color(light: UIColor(hex: 0xFFFCF7), dark: UIColor(hex: 0x1E1C19))
    /// 卡片里的小块
    static let insetFill = Color(light: UIColor(hex: 0xF0EADF), dark: UIColor(hex: 0x2A2824))
    static let hairline = Color(light: UIColor(hex: 0x1B2A3A, alpha: 0.08), dark: UIColor(white: 1, alpha: 0.1))
    static let dot = Color(light: UIColor(hex: 0x1B2A3A, alpha: 0.07), dark: UIColor(white: 1, alpha: 0.06))

    /// 今日计划：新词（焦橙）/ 复习（海军蓝）
    static let newWords = Color("AccentColor")
    static let reviews = Color(light: UIColor(hex: 0x263A50), dark: UIColor(hex: 0x93ABB5))

    // 语义色
    static let success = Color(light: UIColor(hex: 0x315A45), dark: UIColor(hex: 0x8EA499))
    static let danger = Color(light: UIColor(hex: 0xA84E3D), dark: UIColor(hex: 0xB97164))

    // 兼容旧名字
    static var pageBackground: Color { paper }
    static var cardBackground: Color { card }

    // MARK: 首页（照片墙）

    /// 奶油色底
    static let cream = Color(light: UIColor(hex: 0xF5F0E5), dark: UIColor(hex: 0x14120F))
    /// 下方的白色底板
    static let sheet = Color(light: UIColor(hex: 0xFFFCF7), dark: UIColor(hex: 0x1E1C19))
    /// 墨色（首页用）
    static let homeInk = Color(light: UIColor(hex: 0x1B2A3A), dark: UIColor(hex: 0xEEE7D8))
    static let homeMuted = Color(light: UIColor(hex: 0x877E72), dark: UIColor(hex: 0x9C948B))
    /// 蜡笔插画页（欢迎、介绍）的米白纸底，和插画的白纸融在一起；这几页固定浅色
    static let sketchPaper = Color(UIColor(hex: 0xFDFCF5))
    /// 蜡笔插画里的亮黄（字标的光芒、下划线）
    static let sketchYellow = Color(UIColor(hex: 0xF3C934))
    /// 荧光笔（芥末黄调淡）：数字高亮、New! 标签
    static let marker = Color(light: UIColor(hex: 0xE4C47C), dark: UIColor(hex: 0x6E5724))
    /// 地点胶囊（灰蓝调淡）
    static let placeChip = Color(light: UIColor(hex: 0xD0DADF), dark: UIColor(hex: 0x3B4447))
    /// 快门外圈
    static let shutterRing = Color(hex: 0xD5A536)
    /// 手画的闪光线
    static let sparkle = Color(hex: 0xD5A536)
    /// 连续天数胶囊
    static let streakFill = Color(light: UIColor(hex: 0xF2E4C3), dark: UIColor(hex: 0x52421F))
    /// 复习页主题色下面过渡到的浅色
    static let mist = Color(light: UIColor(hex: 0xF2EEE6), dark: UIColor(hex: 0x13110E))
    /// 日期圆点：拍过东西的日子（按词数调深浅）
    static let dayDot = Color(light: UIColor(hex: 0x7896A3), dark: UIColor(hex: 0x93ABB5))
}

// MARK: - 淡底色（复古色调淡）

enum Pastel {
    /// 焦橙
    static let peach = Color(light: UIColor(hex: 0xF1DFD4), dark: UIColor(hex: 0x4F3322))
    /// 学院绿
    static let mint = Color(light: UIColor(hex: 0xE0E6E3), dark: UIColor(hex: 0x233228))
    /// 灰粉
    static let pink = Color(light: UIColor(hex: 0xF0E3E2), dark: UIColor(hex: 0x513E3A))
    /// 酒红
    static let lavender = Color(light: UIColor(hex: 0xE5DCDD), dark: UIColor(hex: 0x362424))
    /// 灰蓝
    static let sky = Color(light: UIColor(hex: 0xDDE5E8), dark: UIColor(hex: 0x384042))
    /// 灰蓝和学院绿之间
    static let aqua = Color(light: UIColor(hex: 0xDAE1E0), dark: UIColor(hex: 0x323E3B))
    /// 芥末黄
    static let butter = Color(light: UIColor(hex: 0xF4E8CD), dark: UIColor(hex: 0x564520))
    /// 鼠尾草绿
    static let sage = Color(light: UIColor(hex: 0xD9DDD5), dark: UIColor(hex: 0x3D4036))
    /// 海军蓝
    static let mist = Color(light: UIColor(hex: 0xE3E5E8), dark: UIColor(hex: 0x1E2328))
    /// 鞋底胶棕
    static let sand = Color(light: UIColor(hex: 0xEDE2D5), dark: UIColor(hex: 0x4D3C2A))
}

extension SceneType {
    /// 没有照片时的占位
    var emoji: String {
        switch self {
        case .restaurant: "☕️"
        case .shopping:   "🛍️"
        case .transport:  "🚌"
        case .signage:    "🪧"
        case .housing:    "🏠"
        case .campus:     "💻"
        case .medical:    "🏥"
        case .bank:       "💳"
        case .sports:     "🌳"
        case .leisure:    "🎭"
        case .tech:       "📱"
        case .general:    "📌"
        }
    }

    var pastel: Color {
        switch self {
        case .restaurant: Pastel.peach
        case .shopping:   Pastel.pink
        case .transport:  Pastel.sky
        case .signage:    Pastel.butter
        case .housing:    Pastel.lavender
        case .campus:     Pastel.mist
        case .medical:    Pastel.aqua
        case .bank:       Pastel.sage
        case .sports:     Pastel.mint
        case .leisure:    Pastel.pink
        case .tech:       Pastel.sky
        case .general:    Pastel.sand
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

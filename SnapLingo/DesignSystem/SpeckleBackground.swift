//
//  SpeckleBackground.swift
//  SnapLingo
//
//  带细小斑点的纸感底纹（像水磨石 / 再生纸）：一块低饱和的实色，上面撒深浅两种小斑点。
//  斑点位置用固定的随机种子生成，每次打开都一样，不会跳动。
//

import SwiftUI

struct SpeckleBackground: View {
    var base: Color
    /// 每多少平方点放一颗斑点（越小越密）
    var areaPerSpeck: CGFloat = 170

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            let dark = scheme == .dark
            var random = SeededRandom(seed: 0x5A1E_1260)
            let count = Int(size.width * size.height / areaPerSpeck)
            for _ in 0..<count {
                let x = random.next() * size.width
                let y = random.next() * size.height
                let kind = random.next()
                let radius = 0.45 + random.next() * random.next() * 1.6
                // 大部分是深色小点，少量浅色点，偶尔一颗稍大的“碎石”
                let color: Color
                if kind < 0.62 {
                    color = dark ? .white.opacity(0.10 + random.next() * 0.08) : .black.opacity(0.09 + random.next() * 0.10)
                } else if kind < 0.92 {
                    color = dark ? .black.opacity(0.30) : .white.opacity(0.55 + random.next() * 0.3)
                } else {
                    color = dark ? .white.opacity(0.14) : Color(hex: 0x6B4A34).opacity(0.16)
                }
                let stretch = 0.75 + random.next() * 0.6
                let rect = CGRect(x: x - radius, y: y - radius * stretch, width: radius * 2, height: radius * 2 * stretch)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// 页面顶部的主题色斑点底纹，往下很快过渡成透明（露出下面的浅灰）；复习页和「我的」共用
struct ThemeWash: View {
    var height: CGFloat = 560
    /// 指定时不跟随用户选的主题色（引导页固定用暖沙，和欢迎页一致）
    var theme: HomeTheme? = nil
    @AppStorage(HomeTheme.storageKey) private var themeRaw = HomeTheme.sky.rawValue

    var body: some View {
        SpeckleBackground(base: (theme ?? HomeTheme(storedValue: themeRaw)).base)
            .frame(height: height)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.5),
                        .init(color: .clear, location: 0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .padding(.top, -160)
            .allowsHitTesting(false)
    }
}

/// 可重复的伪随机数（线性同余），返回 0..<1
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 1_000_000) / 1_000_000
    }
}

/// 首页顶部斑点底纹的主题色，在「我的」里选；默认灰蓝
enum HomeTheme: String, CaseIterable, Identifiable {
    case sky
    case sand
    case lilac
    case sage
    case blush
    case stone

    static let storageKey = "homeTheme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sky: String(localized: "灰蓝", comment: "Theme color name (a muted color)")
        case .sand: String(localized: "暖沙", comment: "Theme color name (a muted color)")
        case .lilac: String(localized: "灰紫", comment: "Theme color name (a muted color)")
        case .sage: String(localized: "灰绿", comment: "Theme color name (a muted color)")
        case .blush: String(localized: "灰粉", comment: "Theme color name (a muted color)")
        case .stone: String(localized: "石灰", comment: "Theme color name (a muted color)")
        }
    }

    var base: Color {
        switch self {
        case .sky: Color(light: UIColor(hex: 0xCED9DE), dark: UIColor(hex: 0x32393A))
        case .sand: Color(light: UIColor(hex: 0xE4D2C0), dark: UIColor(hex: 0x433526))
        case .lilac: Color(light: UIColor(hex: 0xDDD0D2), dark: UIColor(hex: 0x312221))
        case .sage: Color(light: UIColor(hex: 0xCDD2C8), dark: UIColor(hex: 0x363830))
        case .blush: Color(light: UIColor(hex: 0xE8D2D0), dark: UIColor(hex: 0x463733))
        case .stone: Color(light: UIColor(hex: 0xEEE7D8), dark: UIColor(hex: 0x383530))
        }
    }

    init(storedValue: String) {
        self = HomeTheme(rawValue: storedValue) ?? .sky
    }

    /// 主题色调淡：和页面米色底按比例混合，复习页的词夹格子用它，和顶部的斑点底是同一个颜色
    var tint: Color {
        Color(light: Self.mix(base, Theme.mist, 0.62, .light), dark: Self.mix(base, Theme.mist, 0.6, .dark))
    }

    private static func mix(_ a: Color, _ b: Color, _ amount: CGFloat, _ style: UIUserInterfaceStyle) -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let x = UIColor(a).resolvedColor(with: traits), y = UIColor(b).resolvedColor(with: traits)
        var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
        x.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        y.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 * amount + r2 * (1 - amount), green: g1 * amount + g2 * (1 - amount), blue: b1 * amount + b2 * (1 - amount), alpha: 1)
    }
}

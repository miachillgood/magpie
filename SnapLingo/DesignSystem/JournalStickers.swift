//
//  JournalStickers.swift
//  SnapLingo
//
//  手帐风小贴纸：纸胶带、星星、爱心、小叶子、小花……很轻、很小、低饱和，
//  只用来填照片墙的空白，不可点击，读屏也会跳过。
//

import SwiftUI

enum JournalSticker: CaseIterable {
    case tapePlain, tapeGrid, tapeDots, tapeStripes
    case heart, sparkleStar, softStar, asterisk, burst, tinyStars
    case leaf, flower, moon, smiley, squiggle, dots

    /// 空白处放的（稍大一点）
    static let fillers: [JournalSticker] = [.tapeGrid, .leaf, .flower, .tapeDots, .moon, .tapeStripes, .smiley, .tapePlain]
    /// 分隔线旁边放的（很小）
    static let accents: [JournalSticker] = [.heart, .sparkleStar, .burst, .tinyStars, .softStar, .dots, .asterisk, .squiggle]
    /// 从屏幕左边缘露出半截的纸胶带
    static let edgeTapes: [JournalSticker] = [.tapePlain, .tapeGrid, .tapeDots]
}

// MARK: - 颜色（都偏淡）

private enum StickerInk {
    static let yellow = Color(hex: 0xD5A536).opacity(0.6)
    static let paleYellow = Color(hex: 0xE4C47C).opacity(0.8)
    static let grey = Color(light: UIColor(hex: 0x1F1A17, alpha: 0.32), dark: UIColor(white: 1, alpha: 0.28))
    static let beige = Color(light: UIColor(hex: 0xEEE7D8), dark: UIColor(hex: 0x3A352C))
    static let paper = Color(light: UIColor(hex: 0xF1EFEA), dark: UIColor(hex: 0x33312D))
}

struct JournalStickerView: View {
    var kind: JournalSticker
    /// 整体缩放
    var scale: CGFloat = 1

    var body: some View {
        content
            .scaleEffect(scale)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .tapePlain:
            WashiTape(fill: StickerInk.paleYellow, pattern: .plain).rotationEffect(.degrees(-14))
        case .tapeGrid:
            WashiTape(fill: StickerInk.paper, pattern: .grid).rotationEffect(.degrees(10))
        case .tapeDots:
            WashiTape(fill: StickerInk.yellow, pattern: .dots).rotationEffect(.degrees(-8))
        case .tapeStripes:
            WashiTape(fill: StickerInk.paleYellow, pattern: .stripes).rotationEffect(.degrees(12))
        case .heart:
            HeartShape()
                .stroke(StickerInk.yellow, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 18, height: 16)
                .rotationEffect(.degrees(-10))
        case .sparkleStar:
            FourPointStar().fill(StickerInk.grey).frame(width: 16, height: 16)
        case .softStar:
            FourPointStar().fill(StickerInk.paleYellow).frame(width: 20, height: 20)
        case .asterisk:
            StarBurst()
                .stroke(StickerInk.yellow, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 16)
        case .burst:
            SparkleLines()
                .stroke(StickerInk.yellow, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 18, height: 18)
        case .tinyStars:
            HStack(alignment: .top, spacing: 3) {
                FivePointStar().fill(StickerInk.yellow).frame(width: 8, height: 8).offset(y: 4)
                FivePointStar().fill(StickerInk.yellow).frame(width: 7, height: 7).offset(y: 8)
                FivePointStar().fill(StickerInk.yellow).frame(width: 9, height: 9)
            }
        case .leaf:
            LeafSprig()
                .stroke(StickerInk.grey, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 28)
                .rotationEffect(.degrees(12))
        case .flower:
            FlowerShape().fill(StickerInk.paleYellow).frame(width: 22, height: 22)
        case .moon:
            CrescentShape().fill(StickerInk.paleYellow, style: FillStyle(eoFill: true)).frame(width: 20, height: 20)
        case .smiley:
            SmileyShape()
                .stroke(StickerInk.grey, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 20, height: 20)
        case .squiggle:
            Squiggle()
                .stroke(StickerInk.grey, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 30, height: 7)
        case .dots:
            HStack(spacing: 5) {
                Circle().fill(StickerInk.yellow).frame(width: 6, height: 6)
                Circle().fill(StickerInk.grey.opacity(0.6)).frame(width: 6, height: 6)
                Circle().fill(StickerInk.grey).frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - 纸胶带

private struct WashiTape: View {
    enum Pattern { case plain, grid, dots, stripes }
    var fill: Color
    var pattern: Pattern

    var body: some View {
        ZStack {
            fill
            switch pattern {
            case .plain: EmptyView()
            case .grid: GridPattern().stroke(Color.black.opacity(0.07), lineWidth: 0.6)
            case .dots: DotPattern().fill(Color.white.opacity(0.75))
            case .stripes: StripePattern().fill(Color.white.opacity(0.4))
            }
        }
        .frame(width: 52, height: 16)
        .clipShape(TornEnds())
        .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
    }
}

/// 两头撕开的锯齿边
private struct TornEnds: Shape {
    func path(in rect: CGRect) -> Path {
        let teeth = 4
        let step = rect.height / CGFloat(teeth)
        let depth: CGFloat = 2.5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + depth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - depth, y: rect.minY))
        for index in 0..<teeth {
            let y = rect.minY + CGFloat(index) * step
            path.addLine(to: CGPoint(x: rect.maxX, y: y + step / 2))
            path.addLine(to: CGPoint(x: rect.maxX - depth, y: y + step))
        }
        path.addLine(to: CGPoint(x: rect.minX + depth, y: rect.maxY))
        for index in (0..<teeth).reversed() {
            let y = rect.minY + CGFloat(index) * step
            path.addLine(to: CGPoint(x: rect.minX, y: y + step / 2))
            path.addLine(to: CGPoint(x: rect.minX + depth, y: y))
        }
        path.closeSubpath()
        return path
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX + 5
        while x < rect.maxX { path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY)); x += 5 }
        var y = rect.minY + 5
        while y < rect.maxY { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)); y += 5 }
        return path
    }
}

private struct DotPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX + 5
        var row = 0
        while x < rect.maxX {
            let y = row.isMultiple(of: 2) ? rect.height * 0.32 : rect.height * 0.68
            path.addEllipse(in: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2))
            x += 8
            row += 1
        }
        return path
    }
}

private struct StripePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + 3.5, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + 3.5 + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.closeSubpath()
            x += 8
        }
        return path
    }
}

// MARK: - 小图形

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.95))
        path.addCurve(to: CGPoint(x: w * 0.02, y: h * 0.3), control1: CGPoint(x: w * 0.2, y: h * 0.72), control2: CGPoint(x: w * 0.0, y: h * 0.52))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.22), control1: CGPoint(x: w * 0.05, y: h * 0.0), control2: CGPoint(x: w * 0.42, y: h * 0.0))
        path.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.3), control1: CGPoint(x: w * 0.58, y: h * 0.0), control2: CGPoint(x: w * 0.95, y: h * 0.0))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.95), control1: CGPoint(x: w * 1.0, y: h * 0.52), control2: CGPoint(x: w * 0.8, y: h * 0.72))
        return path
    }
}

/// 四角星（边向内凹）
private struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y), control: c)
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY), control: c)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y), control: c)
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.minY), control: c)
        return path
    }
}

private struct FivePointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2, inner = outer * 0.45
        var path = Path()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / 5 - .pi / 2
            let point = CGPoint(x: c.x + CGFloat(cos(angle)) * radius, y: c.y + CGFloat(sin(angle)) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// 一根弯弯的枝条，两片叶子
private struct LeafSprig: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.3, y: h))
        path.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.1), control: CGPoint(x: w * 0.25, y: h * 0.45))
        // 左叶
        path.move(to: CGPoint(x: w * 0.36, y: h * 0.6))
        path.addQuadCurve(to: CGPoint(x: w * 0.02, y: h * 0.32), control: CGPoint(x: w * 0.05, y: h * 0.62))
        path.addQuadCurve(to: CGPoint(x: w * 0.36, y: h * 0.6), control: CGPoint(x: w * 0.32, y: h * 0.3))
        // 右叶
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.35))
        path.addQuadCurve(to: CGPoint(x: w * 0.98, y: h * 0.18), control: CGPoint(x: w * 0.7, y: h * 0.42))
        path.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.35), control: CGPoint(x: w * 0.72, y: h * 0.05))
        return path
    }
}

private struct FlowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let petal = min(rect.width, rect.height) * 0.3
        var path = Path()
        for index in 0..<5 {
            let angle = Double(index) * 2 * .pi / 5 - .pi / 2
            let center = CGPoint(x: c.x + CGFloat(cos(angle)) * petal * 0.9, y: c.y + CGFloat(sin(angle)) * petal * 0.9)
            path.addEllipse(in: CGRect(x: center.x - petal / 2 - 1, y: center.y - petal / 2 - 1, width: petal + 2, height: petal + 2))
        }
        return path
    }
}

/// 月牙：大圆里挖掉一个偏移的圆（用奇偶填充）
private struct CrescentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        path.addEllipse(in: rect.offsetBy(dx: rect.width * 0.32, dy: -rect.height * 0.18))
        return path
    }
}

private struct SmileyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
        path.move(to: CGPoint(x: w * 0.36, y: h * 0.38)); path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.42))
        path.move(to: CGPoint(x: w * 0.64, y: h * 0.38)); path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.42))
        path.move(to: CGPoint(x: w * 0.3, y: h * 0.6))
        path.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.6), control: CGPoint(x: w * 0.5, y: h * 0.8))
        return path
    }
}

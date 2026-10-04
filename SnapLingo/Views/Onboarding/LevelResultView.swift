//
//  LevelResultView.swift
//  SnapLingo
//
//  水平小测的结果：喜鹊拿着地图出场，说清楚以后拍照会重点挑哪类词，再举几个正好这个水平的例子。
//  出场顺序：喜鹊弹出 → 等级名 → 荧光笔划过 → 手写小字 → 两张卡片。
//

import SwiftUI

struct LevelResultView: View {
    var level: CEFRLevel
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var page: Int? = 0

    private var band: LevelBand { LevelBand(level) }

    var body: some View {
        GeometryReader { proxy in
            // Pro Max 这类大屏用效果图的尺寸；普通屏收紧一点，正好一屏放下；SE 可以滚动
            let compact = proxy.size.height < 820
            let birdHeight: CGFloat = proxy.size.height >= 820 ? 170 : (proxy.size.height >= 700 ? 150 : 116)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        hero(compact: compact, birdHeight: birdHeight)
                        focusCard(compact: compact)
                            .padding(.top, compact ? 18 : 24)
                            .modifier(Entrance(appeared: appeared, delay: 0.45, reduceMotion: reduceMotion))
                        exampleCard(compact: compact)
                            .padding(.top, 14)
                            .modifier(Entrance(appeared: appeared, delay: 0.55, reduceMotion: reduceMotion))
                        PageDots(count: band.examples.count, selection: Binding(get: { page ?? 0 }, set: { page = $0 }))
                            .padding(.top, 14)
                            .opacity(appeared ? 1 : 0)
                            .animation(motion(.easeOut(duration: 0.3), delay: 0.7), value: appeared)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                PrimaryButton(title: "开始探索", trailingSymbol: "arrow.right", action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    appeared = true
                }
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }

    // MARK: - 喜鹊 + 等级

    private func hero(compact: Bool, birdHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image("MagpieMascot")
                .resizable()
                .scaledToFit()
                .frame(height: birdHeight)
                .offset(x: -14)
                .scaleEffect(appeared ? 1 : 0.6, anchor: .bottom)
                .opacity(appeared ? 1 : 0)
                .animation(motion(.spring(response: 0.6, dampingFraction: 0.62), delay: 0.05), value: appeared)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    SmallStepsNote(revealed: appeared, reduceMotion: reduceMotion)
                        .offset(x: -6, y: compact ? -8 : -4)
                }
                .padding(.top, compact ? 4 : 14)
                .accessibilityHidden(true)

            Text(level.displayName)
                .font(.system(size: compact ? 40 : 46, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, compact ? 6 : 10)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(motion(.smooth(duration: 0.5), delay: 0.25), value: appeared)
                .accessibilityAddTraits(.isHeader)

            // 手写字体只有英文字形，所有语言都写英文，和欢迎页的口号一样
            Text(verbatim: "You're all set.")
                .font(.handwriting(compact ? 28 : 32))
                .foregroundStyle(Theme.homeInk)
                .padding(.horizontal, 22)
                .padding(.vertical, 2)
                .background {
                    MarkerHighlight(drawn: appeared)
                        .padding(.vertical, 5)
                        .animation(motion(.easeOut(duration: 0.5), delay: 0.6), value: appeared)
                }
                .rotationEffect(.degrees(-3))
                .padding(.top, 2)
                .opacity(appeared ? 1 : 0)
                .animation(motion(.easeOut(duration: 0.3), delay: 0.55), value: appeared)
                .accessibilityHidden(true)

            Text(band.subtitle)
                .font(.system(size: compact ? 15 : 16.5))
                .foregroundStyle(Theme.homeMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, compact ? 10 : 14)
                .opacity(appeared ? 1 : 0)
                .animation(motion(.smooth(duration: 0.5), delay: 0.35), value: appeared)
        }
    }

    // MARK: - 拍照时重点学什么

    private func focusCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            Text("拍照时会重点学这些")
                .font(.callout.weight(.bold))
                .foregroundStyle(Theme.homeInk)
            HStack(alignment: .top, spacing: 8) {
                ForEach(band.focus, id: \.title) { item in
                    FocusTile(item: item, compact: compact)
                }
            }
            // 三格一样高
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 12 : 14)
        .background(Theme.sheet, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }

    // MARK: - 例子

    private func exampleCard(compact: Bool) -> some View {
        let artHeight: CGFloat = compact ? 104 : 118
        return VStack(alignment: .leading, spacing: 10) {
            Text("适合你水平的例子")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.homeMuted)
            // 横向翻页，高度跟着最高的那一页走（释义长的语言也不会被截断）
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(band.examples.enumerated()), id: \.offset) { index, example in
                        ExampleRow(example: example, artHeight: artHeight)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)
        }
        .padding(compact ? 12 : 14)
        .background(Theme.sheet, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

// MARK: - 内容

/// 结果页按水平分三档：每档说清楚拍照时多挑哪类词，再给 3 个正好这个水平的例子
enum LevelBand: CaseIterable {
    case everyday, practical, advanced

    init(_ level: CEFRLevel) {
        switch level {
        case .a1, .a2: self = .everyday
        case .b1, .b2: self = .practical
        case .c1, .c2: self = .advanced
        }
    }

    var subtitle: String {
        switch self {
        case .everyday: String(localized: "Magpie 会先从日常英语开始，等你进步了，再慢慢加入更难的表达。")
        case .practical: String(localized: "日常英语你已经没问题了。Magpie 会多挑通知、租房和办事里的词，帮你读懂更正式的英语。")
        case .advanced: String(localized: "你的英语已经很好了。Magpie 会专挑合同、新闻和地道说法里的难词，常见的词就不打扰你了。")
        }
    }

    var focus: [LevelFocus] {
        switch self {
        case .everyday: [
            LevelFocus(symbol: "signpost.right.and.left", tint: Pastel.peach,
                       title: String(localized: "日常标识"), detail: String(localized: "比如停车、交通")),
            LevelFocus(symbol: "cup.and.heat.waves", tint: Pastel.sage,
                       title: String(localized: "菜单"), detail: String(localized: "比如吃的、喝的")),
            LevelFocus(symbol: "bubble.left.and.bubble.right", tint: Pastel.lavender,
                       title: String(localized: "常用短语"), detail: String(localized: "比如日常对话"))
        ]
        case .practical: [
            LevelFocus(symbol: "megaphone", tint: Pastel.peach,
                       title: String(localized: "通知公告"), detail: String(localized: "比如停水、施工")),
            LevelFocus(symbol: "house", tint: Pastel.sage,
                       title: String(localized: "租房账单"), detail: String(localized: "比如押金、水电")),
            LevelFocus(symbol: "briefcase", tint: Pastel.lavender,
                       title: String(localized: "工作办事"), detail: String(localized: "比如预约、表格"))
        ]
        case .advanced: [
            LevelFocus(symbol: "doc.text", tint: Pastel.peach,
                       title: String(localized: "合同条款"), detail: String(localized: "比如免责、续约")),
            LevelFocus(symbol: "newspaper", tint: Pastel.sage,
                       title: String(localized: "新闻公文"), detail: String(localized: "比如政策、通告")),
            LevelFocus(symbol: "quote.bubble", tint: Pastel.lavender,
                       title: String(localized: "地道说法"), detail: String(localized: "比如习语、俚语"))
        ]
        }
    }

    var examples: [LevelExample] {
        switch self {
        case .everyday: [
            LevelExample(phrase: "Walk-ins welcome", signText: "Walk-ins\nWelcome", sign: .chalkboard,
                         meaning: String(localized: "不用预约，直接进来就行。", comment: "Meaning of the sign 'Walk-ins welcome'")),
            LevelExample(phrase: "Pay at the counter", signText: "PLEASE PAY\nAT COUNTER", sign: .notice,
                         meaning: String(localized: "去柜台付钱。", comment: "Meaning of the sign 'Pay at the counter'")),
            LevelExample(phrase: "Exit only", signText: "EXIT\nONLY", sign: .street(plate: Color(hex: 0x315A45), ink: .white),
                         meaning: String(localized: "这里只能出去，不能进来。", comment: "Meaning of the sign 'Exit only'"))
        ]
        case .practical: [
            LevelExample(phrase: "Out of order", signText: "OUT OF\nORDER", sign: .notice,
                         meaning: String(localized: "坏了，暂时不能用。", comment: "Meaning of the sign 'Out of order'")),
            LevelExample(phrase: "Today's specials", signText: "Today's\nSpecials", sign: .chalkboard,
                         meaning: String(localized: "今天特别推荐的菜，通常只有今天有。", comment: "Meaning of the café sign 'Today's specials'")),
            LevelExample(phrase: "Road works ahead", signText: "ROAD WORKS\nAHEAD", sign: .street(plate: Color(hex: 0xC16D3D), ink: .white),
                         meaning: String(localized: "前面在修路，要减速或者绕行。", comment: "Meaning of the road sign 'Road works ahead'"))
        ]
        case .advanced: [
            LevelExample(phrase: "Subject to availability", signText: "Specials\nsubject to\navailability", sign: .chalkboard,
                         meaning: String(localized: "卖完就没有了，不保证一定有。", comment: "Meaning of 'Subject to availability' on a café board")),
            LevelExample(phrase: "No loitering", signText: "NO\nLOITERING", sign: .street(plate: Color(hex: 0xA84E3D), ink: .white),
                         meaning: String(localized: "不准在这里闲逛、逗留。", comment: "Meaning of the sign 'No loitering'")),
            LevelExample(phrase: "Terms and conditions apply", signText: "Terms and\nconditions\napply", sign: .notice,
                         meaning: String(localized: "有附加条件，具体看细则。", comment: "Meaning of 'Terms and conditions apply' on an offer"))
        ]
        }
    }
}

struct LevelFocus {
    var symbol: String
    var tint: Color
    var title: String
    var detail: String
}

struct LevelExample {
    /// 英文原文，所有语言都不翻译
    var phrase: String
    /// 招牌上的写法（可以换行）
    var signText: String
    var sign: SignArt.Style
    var meaning: String
}

// MARK: - 小部件

private struct FocusTile: View {
    var item: LevelFocus
    var compact: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: item.symbol)
                .font(.system(size: compact ? 22 : 25, weight: .medium))
                .foregroundStyle(Theme.homeInk)
                .frame(width: compact ? 50 : 58, height: compact ? 50 : 58)
                .background(item.tint, in: .circle)
            Text(item.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.homeInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding(.top, compact ? 8 : 10)
            Text(item.detail)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.homeMuted)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, compact ? 10 : 12)
        .padding(.horizontal, 4)
        .background(Theme.mist.opacity(0.6), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ExampleRow: View {
    var example: LevelExample
    var artHeight: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            SignArt(style: example.sign, text: example.signText)
                .frame(width: artHeight * 1.3, height: artHeight)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("正适合你")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.homeInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Pastel.butter, in: .capsule)
                Text(verbatim: example.phrase)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.homeInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(example.meaning)
                    .font(.subheadline)
                    .foregroundStyle(Theme.homeMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PageDots: View {
    var count: Int
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(Theme.homeInk.opacity(index == selection ? 0.85 : 0.15))
                    .frame(width: 8, height: 8)
                    .padding(4)
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(.smooth) { selection = index } }
            }
        }
        .animation(.smooth, value: selection)
        .accessibilityHidden(true)
    }
}

/// 右上角的手写小字，三行错开，下面一道笔画
private struct SmallStepsNote: View {
    var revealed: Bool
    var reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: -6) {
            Text(verbatim: "Small")
            Text(verbatim: "steps").padding(.leading, 10)
            Text(verbatim: "go far").padding(.leading, 22)
            PenStroke()
                .trim(from: 0, to: revealed ? 1 : 0)
                .stroke(Theme.homeInk.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 58, height: 8)
                .padding(.leading, 34)
                .padding(.top, 6)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(1.15), value: revealed)
        }
        .font(.handwriting(21))
        .foregroundStyle(Theme.homeInk.opacity(0.8))
        .rotationEffect(.degrees(-14))
        .opacity(revealed ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.9), value: revealed)
    }
}

/// 稍微往上翘的一笔
private struct PenStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// 从下往上淡入，引导页里按先后顺序出场用
struct Entrance: ViewModifier {
    var appeared: Bool
    var delay: Double
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(reduceMotion ? nil : .smooth(duration: 0.5).delay(delay), value: appeared)
    }
}

// MARK: - 招牌

/// 例子卡上的「照片」：用代码画的招牌，和欢迎页的公交站牌一个思路，所有设备上都清楚，也没有图片版权问题
struct SignArt: View {
    enum Style {
        /// 咖啡店门口的黑板
        case chalkboard
        /// 贴在玻璃门上的打印通知
        case notice
        /// 立在路边的金属牌
        case street(plate: Color, ink: Color)
    }

    var style: Style
    var text: String

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.height / 118
            ZStack {
                switch style {
                case .chalkboard: chalkboard(s, size: geo.size)
                case .notice: notice(s, size: geo.size)
                case .street(let plate, let ink): street(s, size: geo.size, plate: plate, ink: ink)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.colorScheme, .light)
    }

    private func chalkboard(_ s: CGFloat, size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x6B5240), Color(hex: 0x33271F)], startPoint: .top, endPoint: .bottom)
            // 店里的暖光
            Circle()
                .fill(Color(hex: 0xF3C77E).opacity(0.35))
                .frame(width: 90 * s)
                .blur(radius: 18 * s)
                .offset(x: size.width * 0.32, y: -size.height * 0.3)
            Plant(s: s)
                .offset(x: -size.width * 0.38, y: size.height * 0.2)
            VStack(spacing: 0) {
                VStack(spacing: 5 * s) {
                    Text(verbatim: text)
                        .font(.handwriting(17 * s))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineSpacing(-2 * s)
                        .minimumScaleFactor(0.6)
                    Capsule()
                        .fill(.white.opacity(0.7))
                        .frame(width: 38 * s, height: 1.6 * s)
                        .rotationEffect(.degrees(-4))
                }
                .padding(8 * s)
                .frame(width: size.width * 0.6, height: size.height * 0.74)
                .background(Color(hex: 0x262B29), in: .rect(cornerRadius: 3 * s))
                .overlay(RoundedRectangle(cornerRadius: 3 * s).strokeBorder(Color(hex: 0x8A6544), lineWidth: 5 * s))
                // A 字架的两条腿
                HStack(spacing: size.width * 0.42) {
                    Rectangle().fill(Color(hex: 0x6E4F35)).frame(width: 5 * s, height: size.height * 0.12)
                    Rectangle().fill(Color(hex: 0x6E4F35)).frame(width: 5 * s, height: size.height * 0.12)
                }
            }
            .rotationEffect(.degrees(-2))
            .offset(x: size.width * 0.08, y: size.height * 0.05)
            .shadow(color: .black.opacity(0.3), radius: 4 * s, y: 3 * s)
        }
    }

    private func notice(_ s: CGFloat, size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xD3DCE0), Color(hex: 0xA9B7BF)], startPoint: .topLeading, endPoint: .bottomTrailing)
            // 门框
            Rectangle()
                .fill(Color(hex: 0x56636A))
                .frame(width: 10 * s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, size.width * 0.08)
            Rectangle()
                .fill(.white.opacity(0.25))
                .frame(width: 26 * s)
                .rotationEffect(.degrees(20))
                .offset(x: size.width * 0.3)
            Text(verbatim: text)
                .font(.system(size: 14 * s, weight: .heavy))
                .foregroundStyle(Color(hex: 0x1F1A17))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(8 * s)
                .frame(width: size.width * 0.62, height: size.height * 0.66)
                .background(.white)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(hex: 0xA84E3D)).frame(height: 5 * s)
                }
                .shadow(color: .black.opacity(0.18), radius: 3 * s, y: 2 * s)
                .overlay(alignment: .topLeading) { Tape(s: s).rotationEffect(.degrees(-32)).offset(x: -8 * s, y: -2 * s) }
                .overlay(alignment: .topTrailing) { Tape(s: s).rotationEffect(.degrees(32)).offset(x: 8 * s, y: -2 * s) }
                .rotationEffect(.degrees(2))
                .offset(x: size.width * 0.06)
        }
    }

    private func street(_ s: CGFloat, size: CGSize, plate: Color, ink: Color) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x9FC6E6), Color(hex: 0xE4EFF6)], startPoint: .top, endPoint: .bottom)
            // 远处的树
            HStack(spacing: -10 * s) {
                ForEach(0..<4, id: \.self) { index in
                    Circle().fill(Color(hex: index.isMultiple(of: 2) ? 0x7FA77A : 0x6B9768)).frame(width: 34 * s)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: 12 * s)
            Rectangle()
                .fill(Color(hex: 0x8A9196))
                .frame(width: 6 * s, height: size.height * 0.5)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Text(verbatim: text)
                .font(.system(size: 15 * s, weight: .heavy))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 10 * s)
                .padding(.vertical, 8 * s)
                .frame(minWidth: size.width * 0.52)
                .background(plate, in: .rect(cornerRadius: 6 * s, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4 * s, style: .continuous).strokeBorder(ink.opacity(0.9), lineWidth: 1.6 * s).padding(3.5 * s))
                .shadow(color: .black.opacity(0.18), radius: 3 * s, y: 2 * s)
                .offset(y: -size.height * 0.08)
        }
    }

    private struct Tape: View {
        var s: CGFloat
        var body: some View {
            Rectangle()
                .fill(Color(hex: 0xEFE3C2).opacity(0.9))
                .frame(width: 22 * s, height: 8 * s)
        }
    }

    /// 黑板旁边的一盆绿植
    private struct Plant: View {
        var s: CGFloat
        var body: some View {
            ZStack(alignment: .bottom) {
                ForEach(0..<6, id: \.self) { index in
                    Ellipse()
                        .fill(Color(hex: index.isMultiple(of: 2) ? 0x5E8C52 : 0x7BA866))
                        .frame(width: 13 * s, height: 30 * s)
                        .offset(y: -18 * s)
                        .rotationEffect(.degrees(Double(index) * 22 - 55), anchor: .bottom)
                }
                UnevenRoundedRectangle(bottomLeadingRadius: 4 * s, bottomTrailingRadius: 4 * s)
                    .fill(Color(hex: 0xB9A58C))
                    .frame(width: 26 * s, height: 20 * s)
            }
        }
    }
}

#if DEBUG
/// 截图用：已经完成引导时，启动参数 -levelResult A1 单独打开结果页；点按钮就关掉，不改任何设置
struct LevelResultPreview: ViewModifier {
    @State private var level: CEFRLevel?
    @State private var checked = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $level) { level in
                ZStack {
                    OnboardingBackground()
                    LevelResultView(level: level) { self.level = nil }
                }
            }
            .onAppear {
                guard !checked else { return }
                checked = true
                level = OnboardingDebug.value(after: "-levelResult").flatMap { CEFRLevel(code: $0) }
            }
    }
}
#endif

#Preview {
    ZStack {
        OnboardingBackground()
        LevelResultView(level: .a1) {}
    }
}

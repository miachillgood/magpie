//
//  HomeHero.swift
//  SnapLingo
//
//  首页上半部分：字标 + 连续天数、照片堆、句子、单词胶囊、黑色按钮。
//  比例刻意收小，让下面的照片墙在第一屏就露出来。
//  打开时依次出现：照片落下 → 句子浮起 → 荧光笔框住数字 → 闪光线 → 胶囊弹出。
//

import SwiftUI

// MARK: - 内容

/// 句子里的一段
enum HeadlinePiece: Hashable {
    /// 灰色小字，单独一行（今天在）
    case caption(String)
    case text(String)
    /// 场景图标 + 蓝色胶囊里的地点关键词 + 其余部分（Little Bird｜咖啡菜单）
    case place(symbol: String, highlight: String, rest: String)
    /// 荧光笔框住的数字
    case marker(String)
    case emoji(String)

    var plainText: String {
        switch self {
        case .caption(let text), .text(let text), .emoji(let text), .marker(let text): text
        case .place(_, let highlight, let rest): highlight + rest
        }
    }

    var isCaption: Bool {
        if case .caption = self { true } else { false }
    }

    /// 把一句本地化后的话拆成文字和荧光笔数字：`**5**` 是要框住的部分。
    /// 各语言可以按自己的语序放数字（捡到 **5** 个新词 / Picked up **5** new words / **5**個の新しい単語）
    static func phrase(_ text: String) -> [HeadlinePiece] {
        text.components(separatedBy: "**").enumerated().compactMap { index, part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return index.isMultiple(of: 2) ? .text(trimmed) : .marker(trimmed)
        }
    }
}

enum HeroChip {
    /// 英文单词，点开看详情
    case word(VocabWord)
    /// 纯文字（中文释义、建议去的地方）
    case text(String)

    var title: String {
        switch self {
        case .word(let word): word.word
        case .text(let text): text
        }
    }
}

enum HomeHeroAction {
    case openScan(Scan)
    case openWord(VocabWord)
    case study
    case scan
    case showTimeline
}

struct HomeHeroContent {
    var mood: HomeMood
    var label: String
    var lines: [[HeadlinePiece]]
    var chips: [HeroChip]
    var chipsNote: String?
    var action: HomeHeroAction
    var actionTitle: String
    var actionSymbol: String
    var photos: [Scan]
    var stackStyle: PhotoStack.Style

    /// 读屏用的整句
    var sentence: String {
        lines.map { $0.map(\.plainText).joined(separator: " ") }.joined(separator: " ")
    }

    /// 相机图标放在文字前面，箭头放在后面
    var symbolLeads: Bool {
        if case .scan = action { true } else { false }
    }

    /// 把场景名拆成“关键词 + 其余”：英文店名放进胶囊，后面的中日韩文字照常显示
    static func place(symbol: String, title: String, suffix: String = "") -> HeadlinePiece {
        let suffix = suffix.trimmingCharacters(in: .whitespaces).isEmpty ? "" : suffix
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: #"^[A-Za-z0-9'&.\- ]+?(?=\s*[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}])"#, options: .regularExpression) {
            let highlight = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
            let rest = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !highlight.isEmpty && !rest.isEmpty {
                return .place(symbol: symbol, highlight: highlight, rest: rest + suffix)
            }
        }
        return .place(symbol: symbol, highlight: trimmed, rest: suffix)
    }
}

// MARK: - 视图

struct HomeHero: View {
    var content: HomeHeroContent
    /// 斑点底纹的颜色（用户在「我的」里选的主题色）
    var background: Color
    /// 至少占多高：让底纹占掉第一屏的大部分，下面的照片墙只露出一截
    var minHeight: CGFloat
    var metrics: HomeMetrics
    var onAction: (HomeHeroAction) -> Void
    var onProfile: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var k: CGFloat { metrics.widthScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, metrics.sidePadding)

            // 屏幕高、内容放得下时，多出来的空间平均分到这几段留白里
            Spacer(minLength: metrics.gap(4))

            PhotoStack(
                photos: content.photos,
                style: content.stackStyle,
                label: content.label,
                scale: metrics.stackScale,
                appeared: appeared,
                animated: !reduceMotion
            )
            .frame(maxWidth: .infinity)

            Spacer(minLength: metrics.gap(14))

            headline
                .padding(.horizontal, metrics.sidePadding)

            chips
                .padding(.horizontal, metrics.sidePadding)
                .padding(.top, metrics.gap(16))

            Spacer(minLength: metrics.gap(22))

            actionButton
                .frame(maxWidth: .infinity)

            Spacer(minLength: metrics.gap(26))
        }
        .padding(.top, 4)
        .frame(minHeight: minHeight, alignment: .top)
        .background {
            // 斑点纸底一直铺到状态栏后面；往下多铺一截，垫在白色照片墙的圆角后面
            SpeckleBackground(base: background)
                .padding(.top, -160)
                .padding(.bottom, -60)
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    appeared = true
                }
            }
        }
    }

    private func motion(_ animation: Animation, delay: Double) -> Animation? {
        reduceMotion ? nil : animation.delay(delay)
    }

    // MARK: 头部

    private var header: some View {
        HStack {
            Text("Magpie")
                .font(.brand(21))
                .kerning(-0.4)
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 8) {
                Button(action: onProfile) {
                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.homeInk)
                        .frame(width: 36, height: 36)
                        .background(Theme.sheet, in: .circle)
                        .overlay(Circle().strokeBorder(Theme.homeInk.opacity(0.06)))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("我的")
            }
        }
        .frame(height: 44)
    }

    // MARK: 句子

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6 * k) {
            ForEach(Array(content.lines.enumerated()), id: \.offset) { index, line in
                HeadlineLine(
                    pieces: line,
                    size: metrics.headlineSize,
                    scale: k,
                    isLast: index == content.lines.count - 1,
                    appeared: appeared,
                    reduceMotion: reduceMotion
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(motion(.smooth(duration: 0.5), delay: 0.3 + 0.08 * Double(index)), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.sentence)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: 单词胶囊

    private static let chipRotations: [Double] = [-1.5, 1, -1, 1.5]
    private static let chipFills: [Color] = [Theme.sheet, Theme.placeChip, Theme.sheet, Theme.marker.opacity(0.55)]

    private var chips: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let note = content.chipsNote {
                Text(note)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.homeMuted)
            }
            // 只排一行：放不下就少放一个
            ViewThatFits(in: .horizontal) {
                ForEach(Array(stride(from: min(content.chips.count, metrics.maxChips), through: 1, by: -1)), id: \.self) { count in
                    chipRow(count)
                }
            }
        }
    }

    private func chipRow(_ count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(content.chips.prefix(count).enumerated()), id: \.offset) { index, chip in
                chipView(chip, fill: Self.chipFills[index % 4])
                    .rotationEffect(.degrees(Self.chipRotations[index % 4]))
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(motion(.spring(response: 0.45, dampingFraction: 0.6), delay: 0.7 + 0.06 * Double(index)), value: appeared)
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func chipView(_ chip: HeroChip, fill: Color) -> some View {
        switch chip {
        case .word(let word):
            Button { onAction(.openWord(word)) } label: { chipLabel(chip.title, fill: fill) }
                .buttonStyle(.pressable)
                .accessibilityHint("查看这个词")
        case .text(let text):
            chipLabel(text, fill: fill)
        }
    }

    private func chipLabel(_ text: String, fill: Color) -> some View {
        Text(text)
            .font(.system(size: metrics.chipSize, weight: .medium))
            .foregroundStyle(Theme.homeInk)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(fill, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.05)))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    // MARK: 按钮

    private var actionButton: some View {
        Button { onAction(content.action) } label: {
            HStack(spacing: 8) {
                if content.symbolLeads { Image(systemName: content.actionSymbol) }
                Text(content.actionTitle)
                if !content.symbolLeads { Image(systemName: content.actionSymbol) }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // 中文按钮是固定的 190 宽；西语、葡语这类长文字按内容变宽，但不超过屏幕
            .padding(.horizontal, 26)
            .frame(minWidth: 190 * k)
            .frame(maxWidth: metrics.width - metrics.sidePadding * 2)
            .frame(height: 48)
            .fixedSize(horizontal: true, vertical: false)
            .background(Theme.homeInk, in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(motion(.smooth(duration: 0.5), delay: 0.95), value: appeared)
        .sensoryFeedback(.impact(weight: .light), trigger: appeared)
    }
}

// MARK: - 一行句子

/// 每一行尽量不换行：文字放不下时整行字号依次缩小（西语、葡语的句子比中文长）。
/// 地点胶囊放不下时先缩小字号、再用“…”截断；普通句子缩到最小还放不下（英文长句），就折成两行，
/// 绝不比屏幕宽——一行撑出屏幕会把整个首页都挤歪
private struct HeadlineLine: View {
    var pieces: [HeadlinePiece]
    var size: CGFloat
    var scale: CGFloat
    var isLast: Bool
    var appeared: Bool
    var reduceMotion: Bool

    private static let fitFactors: [CGFloat] = [1, 0.88, 0.76, 0.66]
    private static let wrapFactors: [CGFloat] = [1, 0.88, 0.76]

    private var hasPlace: Bool {
        pieces.contains { if case .place = $0 { true } else { false } }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if hasPlace {
                ForEach(Self.fitFactors, id: \.self) { factor in
                    row(size: size * factor)
                }
            } else {
                ForEach(Self.wrapFactors, id: \.self) { factor in
                    row(size: size * factor)
                }
                wrapped(size: size * 0.88)
            }
        }
    }

    /// 折行的写法：整句是一段文字，数字用荧光黄底色标出
    private func wrapped(size: CGFloat) -> some View {
        var text = AttributedString()
        for (index, piece) in pieces.enumerated() {
            if index > 0 { text += AttributedString(" ") }
            if case .marker(let number) = piece {
                var part = AttributedString("\u{2009}\(number)\u{2009}")
                part.font = .brand(size * 1.15)
                part.backgroundColor = Theme.marker
                text += part
            } else {
                var part = AttributedString(piece.plainText)
                part.font = .system(size: size, weight: .heavy)
                text += part
            }
        }
        return Text(text)
            .foregroundStyle(Theme.homeInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(size: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 8 * scale) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                segment(piece, size: size)
            }
            if isLast && !pieces.contains(where: \.isCaption) {
                SparkleLines()
                    .trim(from: 0, to: appeared ? 1 : 0)
                    .stroke(Theme.sparkle, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 22 * scale, height: 22 * scale)
                    .rotationEffect(.degrees(75))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(1.0), value: appeared)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func segment(_ piece: HeadlinePiece, size: CGFloat) -> some View {
        switch piece {
        case .caption(let text):
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.homeMuted)
                .fixedSize()
        case .text(let text):
            Text(text)
                .font(.system(size: size, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .fixedSize()
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: size * 1.05))
                .fixedSize()
        case .place(let symbol, let highlight, let rest):
            Image(systemName: symbol)
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundStyle(Theme.homeInk)
                .fixedSize()
            Text(highlight)
                .font(.system(size: size, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10 * scale)
                .padding(.vertical, 2 * scale)
                // 白色胶囊：任何主题色的斑点底上都清楚
                .background(Theme.sheet, in: .capsule)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .scaleEffect(appeared ? 1 : 0.8, anchor: .leading)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6).delay(0.4), value: appeared)
                .layoutPriority(-1)
            if !rest.isEmpty {
                Text(rest)
                    .font(.system(size: size, weight: .heavy))
                    .foregroundStyle(Theme.homeInk)
                    .lineLimit(1)
                    .layoutPriority(-2)
            }
        case .marker(let number):
            Text(number)
                .font(.brand(size * 1.3))
                .foregroundStyle(Theme.homeInk)
                .padding(.horizontal, 9 * scale)
                .background {
                    MarkerHighlight(drawn: appeared, cornerScale: 0.5)
                        .padding(.vertical, -1)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.65), value: appeared)
                }
                .fixedSize()
        }
    }
}

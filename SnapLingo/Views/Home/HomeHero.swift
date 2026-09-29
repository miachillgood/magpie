//
//  HomeHero.swift
//  SnapLingo
//
//  首页上半部分：字标 + 连续天数、照片堆、带胶囊的大字句子、单词胶囊、黑色按钮。
//  打开时依次出现：照片落下 → 句子浮起 → 荧光笔划过 → 箭头画出 → 胶囊弹出。
//

import SwiftUI

// MARK: - 内容

/// 句子里的一段
enum HeadlinePiece: Hashable {
    case text(String)
    /// 蓝色胶囊：场景图标 + 地点
    case place(String, String)
    /// 荧光笔：大数字 + 单位
    case marker(String, String)
    case emoji(String)

    var plainText: String {
        switch self {
        case .text(let text), .emoji(let text): text
        case .place(_, let title): title
        case .marker(let number, let unit): number + unit
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
    /// 句子行数多的状态字号稍小一点，保证按钮留在第一屏
    var headlineScale: CGFloat = 1
    var action: HomeHeroAction
    var actionTitle: String
    var actionSymbol: String
    var photos: [Scan]
    var stackStyle: PhotoStack.Style

    var sentence: String {
        lines.map { $0.map(\.plainText).joined() }.joined()
    }

    /// 相机图标放在文字前面，箭头放在后面
    var symbolLeads: Bool {
        if case .scan = action { true } else { false }
    }
}

// MARK: - 视图

struct HomeHero: View {
    var content: HomeHeroContent
    var streak: Int
    var metrics: HomeMetrics
    var onAction: (HomeHeroAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var k: CGFloat { metrics.widthScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, metrics.sidePadding)

            PhotoStack(
                photos: content.photos,
                style: content.stackStyle,
                label: content.label,
                scale: metrics.stackScale,
                appeared: appeared,
                animated: !reduceMotion
            )
            .frame(maxWidth: .infinity)
            .padding(.top, metrics.gap(8))

            headline
                .padding(.horizontal, metrics.sidePadding)
                .padding(.top, metrics.gap(24))

            chips
                .padding(.horizontal, metrics.sidePadding)
                .padding(.top, metrics.gap(18))

            actionButton
                .frame(maxWidth: .infinity)
                .padding(.top, metrics.gap(30))
        }
        .padding(.top, 4)
        .padding(.bottom, metrics.gap(36))
        .background(alignment: .top) {
            // 奶油色底一直铺到状态栏后面，柔光叠在上面
            ZStack(alignment: .top) {
                Theme.cream
                MoodGlow(mood: content.mood, drifting: !reduceMotion)
                    .frame(height: 760)
            }
            .padding(.top, -160)
            .allowsHitTesting(false)
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
            Text("SnapLingo")
                .font(.brand(21))
                .kerning(-0.4)
                .foregroundStyle(Theme.homeInk)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if streak > 0 {
                StreakPill(days: streak)
            }
        }
        .frame(height: 44)
    }

    // MARK: 句子

    private var headline: some View {
        let size = metrics.headlineSize * content.headlineScale
        return VStack(alignment: .leading, spacing: 8 * metrics.heightScale) {
            ForEach(Array(content.lines.enumerated()), id: \.offset) { index, line in
                HeadlineLine(pieces: line, size: size, scale: k, appeared: appeared, reduceMotion: reduceMotion)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(motion(.smooth(duration: 0.55), delay: 0.3 + 0.1 * Double(index)), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            HandArrow()
                .trim(from: 0, to: appeared ? 1 : 0)
                .stroke(Theme.homeInk, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 48 * k, height: 54 * k)
                .padding(.trailing, 6)
                .padding(.bottom, 4)
                .animation(motion(.easeOut(duration: 0.6), delay: 1.0), value: appeared)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.sentence)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: 单词胶囊

    private static let chipRotations: [Double] = [-2, 1.5, -1, 2, -1.5, 1]
    private static let chipOffsets: [CGFloat] = [0, 4, 0, 2, 5, 0]

    private var chips: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let note = content.chipsNote {
                Text(note)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.homeMuted)
            }
            FlowLayout(spacing: 10) {
                ForEach(Array(content.chips.prefix(metrics.maxChips).enumerated()), id: \.offset) { index, chip in
                    chipView(chip)
                        .rotationEffect(.degrees(Self.chipRotations[index % 6]))
                        .offset(y: Self.chipOffsets[index % 6])
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        .animation(motion(.spring(response: 0.45, dampingFraction: 0.6), delay: 0.75 + 0.07 * Double(index)), value: appeared)
                }
            }
        }
    }

    @ViewBuilder
    private func chipView(_ chip: HeroChip) -> some View {
        switch chip {
        case .word(let word):
            Button { onAction(.openWord(word)) } label: { chipLabel(chip.title) }
                .buttonStyle(.pressable)
                .accessibilityHint("查看这个词")
        case .text(let text):
            chipLabel(text)
        }
    }

    private func chipLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: metrics.chipSize, weight: .medium))
            .foregroundStyle(Theme.homeInk)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Theme.sheet, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.homeInk.opacity(0.05)))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    // MARK: 按钮

    private var actionButton: some View {
        Button { onAction(content.action) } label: {
            HStack(spacing: 10) {
                if content.symbolLeads { Image(systemName: content.actionSymbol) }
                Text(content.actionTitle)
                if !content.symbolLeads { Image(systemName: content.actionSymbol) }
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.cream)
            .frame(width: min(230 * k, metrics.width - metrics.sidePadding * 2), height: 56)
            .background(Theme.homeInk, in: .capsule)
            .shadow(color: .black.opacity(0.22), radius: 12, y: 10)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(motion(.smooth(duration: 0.5), delay: 1.1), value: appeared)
        .sensoryFeedback(.impact(weight: .light), trigger: appeared)
    }
}

// MARK: - 一行句子

/// 每一行都不换行：文字保持原样，地点胶囊放不下时先缩小字号、再用“…”截断，
/// 这样句子总是固定的行数，按钮不会被挤出第一屏
private struct HeadlineLine: View {
    var pieces: [HeadlinePiece]
    var size: CGFloat
    var scale: CGFloat
    var appeared: Bool
    var reduceMotion: Bool

    var body: some View {
        HStack(spacing: 10 * scale) { segments }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var segments: some View {
        ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
            segment(piece)
        }
    }

    @ViewBuilder
    private func segment(_ piece: HeadlinePiece) -> some View {
        switch piece {
        case .text(let text):
            Text(text)
                .font(.system(size: size, weight: .heavy))
                .foregroundStyle(Theme.homeInk)
                .fixedSize()
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: size * 1.05))
                .fixedSize()
        case .place(let symbol, let title):
            HStack(spacing: 8 * scale) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.7, weight: .semibold))
                Text(title)
                    .font(.system(size: size, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.leading, 14 * scale)
            .padding(.trailing, 18 * scale)
            .frame(height: size * 1.45)
            .background(Theme.placeChip, in: .capsule)
            .layoutPriority(-1)
            .scaleEffect(appeared ? 1 : 0.7, anchor: .leading)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6).delay(0.45), value: appeared)
        case .marker(let number, let unit):
            HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
                Text(number)
                    .font(.brand(size * 1.33))
                Text(unit)
                    .font(.system(size: size, weight: .heavy))
            }
            .foregroundStyle(Theme.homeInk)
            .padding(.horizontal, 10 * scale)
            .background {
                MarkerHighlight(drawn: appeared)
                    .padding(.top, 8 * scale)
                    .padding(.bottom, 2 * scale)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.55).delay(0.7), value: appeared)
            }
            .fixedSize()
        }
    }
}

// MARK: - 连续天数

struct StreakPill: View {
    var days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .symbolRenderingMode(.multicolor)
            Text("连续 \(days) 天")
                .contentTransition(.numericText())
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Theme.homeInk)
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(Theme.streakFill, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("连续学习 \(days) 天")
    }
}

// MARK: - 柔光背景

/// 每种状态一种柔光色：刚拍完暖橘、待复习天蓝、还没拍淡紫、本周回顾薄荷绿
struct MoodGlow: View {
    var mood: HomeMood
    var drifting: Bool

    @Environment(\.colorScheme) private var scheme
    @State private var drift = false

    private struct Light {
        var color: UInt32
        var center: UnitPoint
        var opacity: Double
    }

    private var lights: (Light, Light) {
        switch mood {
        case .captured:
            (Light(color: 0xFFD9A0, center: UnitPoint(x: 1, y: 0.05), opacity: 0.6),
             Light(color: 0xF8C7A2, center: UnitPoint(x: 0, y: 0.45), opacity: 0.5))
        case .review:
            (Light(color: 0xAFCBF6, center: UnitPoint(x: 0.5, y: 0.05), opacity: 0.65),
             Light(color: 0xC9DDFA, center: UnitPoint(x: 0, y: 0.5), opacity: 0.6))
        case .empty:
            (Light(color: 0xD4C3F8, center: UnitPoint(x: 1, y: 0.12), opacity: 0.65),
             Light(color: 0xE6DDFC, center: UnitPoint(x: 0, y: 0.45), opacity: 0.65))
        case .weekly:
            (Light(color: 0xB1DFBE, center: UnitPoint(x: 0, y: 0.22), opacity: 0.65),
             Light(color: 0xFFE69C, center: UnitPoint(x: 1, y: 0.08), opacity: 0.55))
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, 1) * 0.95
            let dim = scheme == .dark ? 0.35 : 1
            ZStack {
                glow(lights.0, radius: radius, dim: dim)
                glow(lights.1, radius: radius * 0.9, dim: dim)
            }
            .offset(x: drift ? 12 : -6, y: drift ? -10 : 4)
            .scaleEffect(drift ? 1.06 : 1)
        }
        .onAppear {
            guard drifting else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }

    private func glow(_ light: Light, radius: CGFloat, dim: Double) -> some View {
        let color = Color(hex: light.color)
        return RadialGradient(
            colors: [color.opacity(light.opacity * dim), color.opacity(0)],
            center: light.center,
            startRadius: 0,
            endRadius: radius
        )
    }
}

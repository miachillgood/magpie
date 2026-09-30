//
//  Components.swift
//  SnapLingo
//
//  可复用的基础组件。页面里不要再手写圆角、徽章和卡片样式。
//

import SwiftUI

// MARK: - 卡片

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = Spacing.md
    var radius: CGFloat = Radius.card
    var fill: Color = Theme.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 14, y: 6)
    }
}

extension View {
    func card(padding: CGFloat = Spacing.md, radius: CGFloat = Radius.card, fill: Color = Theme.card) -> some View {
        modifier(CardModifier(padding: padding, radius: radius, fill: fill))
    }

    /// 柔和的浮起阴影（贴纸、芯片）
    func softShadow(_ strength: Double = 1) -> some View {
        modifier(SoftShadow(strength: strength))
    }
}

private struct SoftShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var strength: Double

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity((scheme == .dark ? 0.35 : 0.1) * strength), radius: 10, y: 4)
    }
}

// MARK: - 背景

/// 纸张 + 细点阵（像手帐本）
struct PaperBackground: View {
    var body: some View {
        Theme.paper
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 18
                    let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 2, height: 2))
                    var y: CGFloat = 8
                    while y < size.height {
                        var x: CGFloat = 8
                        while x < size.width {
                            context.fill(dot.offsetBy(dx: x, dy: y), with: .color(Theme.dot))
                            x += spacing
                        }
                        y += spacing
                    }
                }
            }
            .ignoresSafeArea()
    }
}

/// 缓慢流动的网格渐变（顶部氛围光）
struct MeshBackdrop: View {
    var colors: [Color] = [Pastel.peach, Pastel.pink, Pastel.lavender]
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !animated)) { timeline in
            let t = Float(timeline.date.timeIntervalSinceReferenceDate)
            let wobble = animated ? 0.08 * sin(t * 0.35) : 0
            let wobble2 = animated ? 0.08 * cos(t * 0.27) : 0
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5 + wobble, 0.5 + wobble2], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    colors[0], colors[1 % colors.count], colors[2 % colors.count],
                    colors[1 % colors.count], colors[2 % colors.count], colors[0],
                    Theme.paper, Theme.paper, Theme.paper
                ]
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - 按钮

/// 主按钮：墨黑胶囊
struct PrimaryButton: View {
    var title: LocalizedStringKey
    var symbol: String?
    var trailingSymbol: String?
    var action: () -> Void

    init(title: LocalizedStringKey, symbol: String? = nil, trailingSymbol: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.trailingSymbol = trailingSymbol
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
                if let trailingSymbol { Image(systemName: trailingSymbol).font(.subheadline.weight(.bold)) }
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(Theme.onInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.ink, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
    }
}

/// 次按钮：白色胶囊
struct SecondaryButton: View {
    var title: LocalizedStringKey
    var symbol: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.card, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
    }
}

/// 圆形图标按钮
struct CircleIconButton: View {
    var symbol: String
    var size: CGFloat = 44
    var filled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(filled ? Theme.onInk : Theme.ink)
                .frame(width: size, height: size)
                .background(filled ? Theme.ink : Theme.card, in: .circle)
                .softShadow(filled ? 0.6 : 1)
        }
        .buttonStyle(.pressable)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Emoji 图块

/// 马卡龙色圆角方块里放一个 emoji（像插画图标）
struct EmojiTile: View {
    var emoji: String
    var color: Color
    var size: CGFloat = 44

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.52))
            .frame(width: size, height: size)
            .background(color, in: .rect(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - 胶囊标签

struct Pill: View {
    enum Style {
        case neutral
        case brand
        case tinted(Color)
        case solid(Color)
        case ink
    }

    private var label: Text
    var symbol: String?
    var emoji: String?
    var style: Style = .neutral

    init(text: LocalizedStringKey, symbol: String? = nil, emoji: String? = nil, style: Style = .neutral) {
        self.init(label: Text(text), symbol: symbol, emoji: emoji, style: style)
    }

    /// 已经本地化好的文字（场景名、状态名）原样显示；字面量仍然走上面的本地化版本
    @_disfavoredOverload
    init<S: StringProtocol>(text: S, symbol: String? = nil, emoji: String? = nil, style: Style = .neutral) {
        self.init(label: Text(text), symbol: symbol, emoji: emoji, style: style)
    }

    private init(label: Text, symbol: String?, emoji: String?, style: Style) {
        self.label = label
        self.symbol = symbol
        self.emoji = emoji
        self.style = style
    }

    var body: some View {
        HStack(spacing: 4) {
            if let emoji { Text(emoji) }
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            label
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background(background, in: .capsule)
    }

    private var foreground: Color {
        switch style {
        case .neutral: .secondary
        case .brand: Theme.brand
        case .tinted: Theme.ink
        case .solid: .white
        case .ink: Theme.onInk
        }
    }

    private var background: Color {
        switch style {
        case .neutral: Theme.insetFill
        case .brand: Theme.brandSoft
        case .tinted(let color): color
        case .solid(let color): color
        case .ink: Theme.ink
        }
    }
}

/// 单词贴纸：白色胶囊 + 衬线英文 + 中文释义（浮在照片上）
struct WordSticker: View {
    var word: String
    var gloss: String
    var compact = false
    var highlighted = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Text(word)
                .font(.word(compact ? 12 : 15, weight: .bold))
                .foregroundStyle(highlighted ? Theme.onInk : Theme.ink)
            if !gloss.isEmpty {
                Text(gloss)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(highlighted ? Theme.onInk.opacity(0.75) : .secondary)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 7)
        .background(highlighted ? Theme.ink : Theme.card, in: .capsule)
        .fixedSize()
        .softShadow()
    }
}

// MARK: - 区块标题

struct SectionHeader<Trailing: View>: View {
    var title: LocalizedStringKey
    var emoji: String?
    var subtitle: LocalizedStringKey?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let emoji { Text(emoji) }
                    Text(title)
                }
                .font(.title3.weight(.heavy))
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Spacing.xs)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey, emoji: String? = nil, subtitle: LocalizedStringKey? = nil) {
        self.init(title: title, emoji: emoji, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - 统计格

struct StatTile: View {
    var value: Int
    var label: LocalizedStringKey
    var emoji: String
    var color: Color = Pastel.sand
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value, format: .number)
                    .font(.statNumber)
                    .contentTransition(.numericText())
                if !suffix.isEmpty {
                    Text(suffix).font(.headline.weight(.heavy))
                }
                Spacer(minLength: 2)
                Text(emoji).font(.title3)
            }
            .foregroundStyle(Theme.ink)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 筛选芯片

struct FilterChip: View {
    private var title: Text
    var emoji: String?
    var count: Int?
    var isSelected: Bool
    var action: () -> Void

    init(title: LocalizedStringKey, emoji: String? = nil, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.init(label: Text(title), emoji: emoji, count: count, isSelected: isSelected, action: action)
    }

    /// 已经本地化好的文字（筛选项名）原样显示；字面量仍然走上面的本地化版本
    @_disfavoredOverload
    init<S: StringProtocol>(title: S, emoji: String? = nil, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.init(label: Text(title), emoji: emoji, count: count, isSelected: isSelected, action: action)
    }

    private init(label: Text, emoji: String?, count: Int?, isSelected: Bool, action: @escaping () -> Void) {
        self.title = label
        self.emoji = emoji
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let emoji { Text(emoji) }
                title
                if let count {
                    Text("\(count)")
                        .foregroundStyle(isSelected ? Theme.onInk.opacity(0.6) : .secondary)
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isSelected ? Theme.onInk : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Theme.ink : Theme.card, in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Theme.hairline))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 流式布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        var y: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                y += current.height + spacing
                current = Row(y: y)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - 彩带

/// 完成时的彩带（Canvas 粒子，无需图片资源）
struct ConfettiView: View {
    var trigger: Int

    @State private var startDate: Date?
    @State private var pieces: [Piece] = (0..<70).map { _ in Piece() }
    private let colors: [Color] = [Color(hex: 0xF45B2A), Color(hex: 0xFFC53D), Color(hex: 0x6B5CF0), Color(hex: 0x1FA463), Color(hex: 0xFF8FB1), Color(hex: 0x3DD6F0)]

    struct Piece {
        var x = Double.random(in: 0...1)
        var delay = Double.random(in: 0...0.35)
        var speed = Double.random(in: 0.55...1.1)
        var drift = Double.random(in: -0.25...0.25)
        var spin = Double.random(in: 2...9)
        var size = Double.random(in: 6...11)
        var colorIndex = Int.random(in: 0..<6)
        var isCircle = Bool.random()
    }

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let elapsed = timeline.date.timeIntervalSince(startDate)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0, t < 3.2 else { continue }
                    let y = -20 + t * t * 0.5 * size.height * piece.speed + t * 60
                    let x = piece.x * size.width + sin(t * piece.spin) * 18 + piece.drift * size.width * t
                    var copy = context
                    copy.opacity = max(0, 1 - t / 3.2)
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / (piece.isCircle ? 1 : 2))
                    let path = piece.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    copy.fill(path, with: .color(colors[piece.colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger, initial: true) { _, value in
            if value > 0 { startDate = Date() }
        }
        .accessibilityHidden(true)
    }
}

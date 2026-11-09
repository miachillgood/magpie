//
//  WatchReviewView.swift
//  MagpieWatch
//
//  一张一张复习，全靠手势：
//  - 点一下卡片：翻面看意思
//  - 右滑：会　左滑：不会　上滑：已掌握（以后不再复习，4 秒内可以撤销）
//  - 捏两下（Double Tap）：正面时翻面，背面时等于「会」—— 一只手就能复习完一轮
//  「不会」的词和手机上一样，隔 4 张再出现一次（最多 3 次），重练的结果不发回手机。
//

import SwiftUI

struct WatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [Item]
    @State private var position = 0
    @State private var revealed = false
    @State private var offset: CGSize = .zero
    /// 刚上滑掌握的卡：4 秒内可以撤销，过了才发给手机
    @State private var pendingMastery: PendingMastery?
    @State private var feedback: Feedback?
    /// 卡片正在飞走：这时再滑、再捏都不算（避免一张卡记两次）
    @State private var committing = false
    /// 手表每评一张，首页的剩余卡片就少一张，这个页面会被重新创建：总数要存在 State 里，不能跟着变
    @State private var total: Int
    @State private var accent: String
    /// 前几张卡底下提示一下可以左右滑，学会了就不再显示
    @AppStorage("watchSwipeHintCount") private var hintCount = 0

    private static let retryGap = 4
    private static let maxAttempts = 3
    /// 拖过这么远松手就算数
    private static let threshold: CGFloat = 45

    private struct Item: Identifiable {
        let id = UUID()
        let card: WatchCard
        let attempt: Int
    }

    private struct PendingMastery {
        let item: Item
        let task: Task<Void, Never>
    }

    private enum Choice {
        case forgot, know, mastered

        /// ReviewRating 的 rawValue
        var ratingRaw: Int {
            switch self {
            case .forgot: 0
            case .know: 4
            case .mastered: 5
            }
        }

        var color: Color {
            switch self {
            case .forgot: .red
            case .know: .green
            case .mastered: .yellow
            }
        }

        var symbol: String {
            switch self {
            case .forgot: "xmark"
            case .know: "checkmark"
            case .mastered: "star.fill"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .forgot: "不会"
            case .know: "会"
            case .mastered: "掌握"
            }
        }
    }

    private struct Feedback: Equatable {
        let id = UUID()
        let choice: Choice
    }

    init(cards: [WatchCard]) {
        _queue = State(initialValue: cards.map { Item(card: $0, attempt: 0) })
        _total = State(initialValue: cards.count)
        _accent = State(initialValue: WatchStore.shared.snapshot?.accent ?? "en-US")
    }

    private var current: Item? { position < queue.count ? queue[position] : nil }
    /// 第几张新卡（重练的不算）
    private var seen: Int { min(queue.prefix(position + 1).filter { $0.attempt == 0 }.count, total) }

    var body: some View {
        VStack(spacing: 6) {
            if let item = current {
                card(item)
                    .id(item.id)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .overlay(alignment: .bottom) {
                        if pendingMastery != nil {
                            undoPill
                                .padding(.bottom, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
            } else {
                finished
                    .overlay(alignment: .bottom) {
                        if pendingMastery != nil { undoPill }
                    }
            }
            footer
                .padding(.bottom, 6)
        }
        .frame(maxHeight: .infinity)
        // 底下的安全区在手表上是空着的一条：让卡片用满屏幕
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle(Text(verbatim: "\(seen)/\(total)"))
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(backgroundTint.gradient, for: .navigation)
        .background { primaryAction }
        .sensoryFeedback(trigger: feedback) { _, new in
            switch new?.choice {
            case .know: .success
            case .forgot: .error
            case .mastered: .impact(weight: .heavy)
            case nil: nil
            }
        }
        .sensoryFeedback(.selection, trigger: revealed)
        .onDisappear { finishPendingMastery() }
    }

    // MARK: - 卡片

    private func card(_ item: Item) -> some View {
        let choice = Self.choice(for: offset, committed: false)
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(choice?.color ?? .white.opacity(0.12), lineWidth: choice == nil ? 1 : 3)
                }

            ZStack {
                front(item.card)
                    .opacity(revealed ? 0 : 1)
                back(item.card)
                    .opacity(revealed ? 1 : 0)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotation3DEffect(.degrees(revealed && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            if let choice {
                badge(choice)
                    .opacity(Double(min(1, dragDistance / Self.threshold)))
            }
        }
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width) / 14))
        .contentShape(.rect(cornerRadius: 22))
        .onTapGesture { flip() }
        .gesture(drag(item))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("点一下看意思"))
        .accessibilityAction(named: Text("会")) { rate(item, .know) }
        .accessibilityAction(named: Text("不会")) { rate(item, .forgot) }
        .accessibilityAction(named: Text("掌握")) { rate(item, .mastered) }
        .accessibilityAction(named: Text("翻面")) { flip() }
    }

    private func front(_ card: WatchCard) -> some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()
                speakButton(card.word)
            }
            Spacer(minLength: 0)
            Text(verbatim: card.word)
                .font(.system(.title2, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            if !card.phonetic.isEmpty {
                Text(verbatim: card.phonetic)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("点一下看意思")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func back(_ card: WatchCard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: card.word)
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
                speakButton(card.word)
            }
            if !card.meaning.isEmpty {
                Text(verbatim: card.meaning)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if !card.example.isEmpty {
                Text(verbatim: card.example)
                    .font(.footnote.italic())
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
            }
            if !card.exampleTranslation.isEmpty {
                Text(verbatim: card.exampleTranslation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speakButton(_ word: String) -> some View {
        Button {
            speak(word)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.footnote)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(Text("朗读"))
    }

    /// 拖动时卡片中间浮出的「✓ 会」「✕ 不会」「★ 掌握」
    private func badge(_ choice: Choice) -> some View {
        Label(choice.title, systemImage: choice.symbol)
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(choice.color, in: .capsule)
    }

    private var finished: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Text(verbatim: "🎉")
                .font(.largeTitle)
            Text("复习完了")
                .font(.headline)
            Button("完成") { dismiss() }
            Spacer(minLength: 0)
        }
    }

    /// 刚上滑掌握：浮在卡片底部的「已掌握 · 撤销」（屏幕最底下那条点不到，所以放在卡片上）
    private var undoPill: some View {
        Button {
            undoMastery()
        } label: {
            Label("已掌握 · 撤销", systemImage: "arrow.uturn.backward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.yellow, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    /// 底下一行：滑动提示 > 进度线
    @ViewBuilder
    private var footer: some View {
        if hintCount < 3, current != nil {
            Text("← 不会 · 会 →")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if total > 0 {
            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.tint)
                            .frame(width: proxy.size.width * CGFloat(seen) / CGFloat(total))
                    }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
            .accessibilityHidden(true)
        }
    }

    // MARK: - 手势

    private var dragDistance: CGFloat {
        max(abs(offset.width), -offset.height)
    }

    /// 往哪个方向拖；committed 时要拖过门槛才算
    private static func choice(for offset: CGSize, committed: Bool) -> Choice? {
        let limit: CGFloat = committed ? threshold : 8
        if -offset.height > limit, -offset.height > abs(offset.width) { return .mastered }
        if offset.width > limit { return .know }
        if offset.width < -limit { return .forgot }
        return nil
    }

    private func drag(_ item: Item) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // 从屏幕左边缘开始的拖动留给系统的「返回」
                guard value.startLocation.x > 15 else { return }
                offset = CGSize(width: value.translation.width, height: min(value.translation.height, 20))
            }
            .onEnded { value in
                guard value.startLocation.x > 15,
                      let choice = Self.choice(for: offset, committed: true)
                else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { offset = .zero }
                    return
                }
                rate(item, choice)
            }
    }

    /// 捏两下：正面翻面，背面算「会」。按钮本身看不见，也不接收点按
    /// （不然它会盖住整个页面，点哪里都变成翻面）
    private var primaryAction: some View {
        Button {
            guard let item = current else { return }
            if revealed { rate(item, .know) } else { flip() }
        } label: {
            Text(revealed ? "会" : "翻面")
        }
        .handGestureShortcut(.primaryAction)
        .frame(width: 1, height: 1)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var backgroundTint: Color {
        guard let choice = Self.choice(for: offset, committed: false) else { return Color.accentColor.opacity(0.25) }
        return choice.color.opacity(0.15 + 0.35 * Double(min(1, dragDistance / Self.threshold)))
    }

    // MARK: - 动作

    private func flip() {
        guard current != nil else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8)) {
            revealed.toggle()
        }
    }

    private func rate(_ item: Item, _ choice: Choice) {
        guard !committing else { return }
        committing = true
        // 上一张还在等撤销：新的评分一来就算它定了
        finishPendingMastery()
        feedback = Feedback(choice: choice)
        if hintCount < 3 { hintCount += 1 }

        // 卡片朝滑的方向飞走
        let fly: CGSize = switch choice {
        case .know: CGSize(width: 260, height: offset.height)
        case .forgot: CGSize(width: -260, height: offset.height)
        case .mastered: CGSize(width: offset.width, height: -320)
        }
        withAnimation(.easeIn(duration: 0.18)) { offset = fly }

        Task {
            try? await Task.sleep(for: .milliseconds(180))
            advance(after: item, choice)
        }
    }

    private func advance(after item: Item, _ choice: Choice) {
        switch choice {
        case .know, .forgot:
            if item.attempt == 0 {
                WatchStore.shared.record(item.card, ratingRaw: choice.ratingRaw)
            }
            if choice == .forgot && item.attempt + 1 < Self.maxAttempts {
                let index = min(position + 1 + Self.retryGap, queue.count)
                queue.insert(Item(card: item.card, attempt: item.attempt + 1), at: index)
            }
        case .mastered:
            // 4 秒后才真正发给手机，在这之前可以撤销
            let task = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                finishPendingMastery()
            }
            withAnimation(.snappy) { pendingMastery = PendingMastery(item: item, task: task) }
        }
        revealed = false
        offset = .zero
        committing = false
        withAnimation(.snappy) { position += 1 }
    }

    private func finishPendingMastery() {
        guard let pending = pendingMastery else { return }
        pending.task.cancel()
        WatchStore.shared.record(pending.item.card, ratingRaw: Choice.mastered.ratingRaw)
        withAnimation(.snappy) { pendingMastery = nil }
    }

    private func undoMastery() {
        guard let pending = pendingMastery else { return }
        pending.task.cancel()
        withAnimation(.snappy) {
            pendingMastery = nil
            revealed = false
            offset = .zero
            position = max(0, position - 1)
        }
    }

    private func speak(_ text: String) {
        WatchSpeech.speak(text, accent: accent)
    }
}

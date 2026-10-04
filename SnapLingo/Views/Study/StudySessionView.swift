//
//  StudySessionView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct StudySessionView: View {
    let request: StudyRequest

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var session: StudySession?
    @State private var extraNew = 0

    var body: some View {
        ZStack {
            PaperBackground()
            MeshBackdrop(colors: backdropColors)
                .frame(maxHeight: .infinity, alignment: .top)
                // 结算页是干净的米色底，和效果图一致
                .opacity(session?.isFinished == true ? 0 : 0.9)
                .animation(.easeInOut(duration: 0.6), value: session?.current?.id)
            if let session {
                if session.isFinished {
                    SessionCompleteView(session: session, onContinue: { continueToday() }, onMore: { learnMore() }, onDone: { finish() })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    StudyCardsView(session: session, onClose: { finish() })
                        .transition(.opacity)
                }
            }
        }
        .overlay(alignment: .bottom) {
            // 撤销条放在最外层：最后一张点了「太简单」直接进结算页时也能撤销
            if let session, let undo = session.pendingUndo {
                UndoBar(word: undo.word.word) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        session.undoLast(context: context)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 128)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: undo.log?.id ?? undo.word.id) {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth) { session.dismissUndo() }
                }
            }
        }
        .animation(.smooth, value: session?.pendingUndo != nil)
        .animation(.smooth, value: session?.isFinished)
        .task {
            if case .today(let extra) = request.scope { extraNew = extra }
            session = StudySession.make(scope: request.scope, context: context)
        }
    }

    private var backdropColors: [Color] {
        let scene = session?.current?.word.latestScan?.scene ?? .general
        return [scene.pastel, Pastel.pink, Pastel.lavender]
    }

    /// 今天的计划还没学完：再开一轮（从照片、某一天进来的也回到今日计划）
    private func continueToday() {
        withAnimation(.smooth) {
            session = StudySession.make(scope: .today(extraNew: extraNew), context: context)
        }
    }

    private func learnMore() {
        extraNew += 5
        withAnimation(.smooth) {
            session = StudySession.make(scope: .today(extraNew: extraNew), context: context)
        }
    }

    private func finish() {
        StudyReminder.refresh(context: context)
        ExplanationQueue.shared.run(context: context)
        dismiss()
    }
}

// MARK: - 卡片学习

private struct StudyCardsView: View {
    @Bindable var session: StudySession
    var onClose: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: Spacing.md) {
            topBar
            if let card = session.current {
                FlipCard(flipped: session.revealed) {
                    CardFront(card: card)
                } back: {
                    CardBack(word: card.word)
                }
                .id(card.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .onTapGesture { reveal() }
                .accessibilityAction(named: "显示释义") { reveal() }

                controls
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xs)
        .sensoryFeedback(trigger: session.ratingCount) { _, _ in
            session.lastRating == .again ? .impact(weight: .light) : .impact(flexibility: .soft)
        }
    }

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            CircleIconButton(symbol: "xmark", size: 40, action: onClose)
                .accessibilityLabel("结束学习")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.card.opacity(0.8))
                    Capsule()
                        .fill(Theme.brand)
                        .frame(width: max(proxy.size.width * session.progress, session.progress > 0 ? 12 : 0))
                }
            }
            .frame(height: 12)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: session.progress)
            .accessibilityElement()
            .accessibilityLabel("进度 \(session.completedCount) / \(session.initialCount)")

            Text("\(session.completedCount)/\(session.initialCount)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.ink.opacity(0.7))
                .contentTransition(.numericText())
        }
        .padding(.top, Spacing.xs)
    }

    /// 先问会不会：会 / 太简单直接下一张；不会就翻过来看意思，看完点“下一个”
    @ViewBuilder
    private var controls: some View {
        if session.missedCurrent {
            HStack(spacing: Spacing.sm) {
                // 看完释义可以返回正面再看一眼单词和照片；在正面时可以再去看释义
                Button { reveal() } label: {
                    Group {
                        if session.revealed {
                            Label("返回", systemImage: "chevron.left")
                        } else {
                            Label("看释义", systemImage: "text.book.closed")
                        }
                    }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, Spacing.md)
                        .frame(height: 56)
                        .background(Theme.card, in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.hairline))
                        .contentShape(.capsule)
                }
                .buttonStyle(.pressable)
                .fixedSize()

                PrimaryButton(title: "下一个", trailingSymbol: "chevron.right") {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        session.rate(.again, context: context)
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: Spacing.sm) {
                ForEach(ReviewRating.buttons) { rating in
                    RatingButton(rating: rating) {
                        choose(rating)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
        }
    }

    private func choose(_ rating: ReviewRating) {
        if rating == .again {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                session.missedCurrent = true
                session.revealed = true
            }
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                session.rate(rating, context: context)
            }
        }
    }

    /// 点卡片可以翻过来看一眼、再翻回去；评分还是用下面的按钮
    private func reveal() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            session.revealed.toggle()
        }
    }
}

// MARK: - 翻牌

/// 3D 翻牌：角度过半时切换正反面
private struct FlipCard<Front: View, Back: View>: View {
    var flipped: Bool
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back

    var body: some View {
        FlipContainer(angle: flipped ? 180 : 0, front: front, back: back)
    }
}

private struct FlipContainer<Front: View, Back: View>: View, Animatable {
    var angle: Double
    var front: Front
    var back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            if angle < 90 {
                front
            } else {
                back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Radius.hero, style: .continuous))
        .clipShape(.rect(cornerRadius: Radius.hero, style: .continuous))
        .softShadow(1.3)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

// MARK: - 正面

private struct CardFront: View {
    let card: StudySession.Card

    @State private var showingPhoto = false

    var body: some View {
        let word = card.word
        VStack(spacing: 0) {
            if let scan = word.latestScan {
                WordInPhotoView(word: word, scan: scan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Label { Text(scan.displayTitle) } icon: { IconImage(name: scan.scene.iconName, size: 18) }
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 7)
                            .background(Theme.card, in: .capsule)
                            .softShadow()
                            .padding(Spacing.sm)
                    }
                    .overlay(alignment: .topTrailing) {
                        // 看整张照片
                        Button { showingPhoto = true } label: {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.black.opacity(0.45), in: .circle)
                        }
                        .buttonStyle(.pressable)
                        .padding(Spacing.sm)
                        .accessibilityLabel("查看整张照片")
                    }
                    .padding(10)
                    .accessibilityLabel("在「\(scan.displayTitle)」里看到的词")
                    .fullScreenCover(isPresented: $showingPhoto) {
                        FullPhotoView(scan: scan)
                    }
            }

            Spacer(minLength: Spacing.md)

            VStack(spacing: Spacing.sm) {
                Text(word.word)
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                SpeakButton(text: word.word)
                    .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.md)

            Text(card.isNew ? "认识这个词吗？" : "还记得它的意思吗？")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.lg)
        }
    }
}

// MARK: - 背面

private struct CardBack: View {
    let word: VocabWord

    @AppStorage(AIConsent.storageKey) private var consentRaw = AIConsent.State.undecided.rawValue

    private var pendingText: String {
        consentRaw == AIConsent.State.granted.rawValue
            ? String(localized: "解释还在生成中，先凭印象评分吧")
            : String(localized: "AI 释义已关闭")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                WordHeader(word: word, compact: true)

                Text(word.explanationStatus == .ready ? word.explanation : (word.gloss.isEmpty ? pendingText : word.gloss))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)

                if !word.exampleSentence.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HighlightedText(text: word.exampleSentence, highlight: word.word)
                            .font(.word(18, weight: .medium))
                        Text(word.exampleTranslation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.insetFill, in: .rect(cornerRadius: Radius.small, style: .continuous))
                }

                if !word.sceneNote.isEmpty {
                    Text("💡 \(word.sceneNote)")
                        .font(.subheadline)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Pastel.butter, in: .rect(cornerRadius: Radius.small, style: .continuous))
                }

                if !word.contextSnippet.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("📷 在照片里")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.secondary)
                        HighlightedText(text: word.contextSnippet, highlight: word.word)
                            .font(.word(16, weight: .regular))
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - 评分按钮

private extension ReviewRating {
    /// 按钮上的喜鹊
    var mascot: String {
        switch self {
        case .again: "RatingAgain"
        case .easy:  "RatingEasy"
        default:     "RatingGood"
        }
    }

    /// 按钮上的小字：点了会怎样
    var buttonHint: String {
        switch self {
        case .again: String(localized: "查看提示", comment: "Rating button subtitle: flips the card to show the meaning")
        case .easy:  String(localized: "不再复习", comment: "Rating button subtitle: this word leaves the review queue")
        default:     String(localized: "继续复习", comment: "Rating button subtitle: keep reviewing this word on schedule")
        }
    }
}

// MARK: - 整张照片

/// 全屏看拍的那张照片，可以双指放大
private struct FullPhotoView: View {
    let scan: Scan

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image = scan.fullImage ?? scan.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(min(max(zoom * pinch, 1), 4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        MagnifyGesture()
                            .updating($pinch) { value, state, _ in state = value.magnification }
                            .onEnded { value in zoom = min(max(zoom * value.magnification, 1), 4) }
                    )
                    .onTapGesture(count: 2) { withAnimation(.smooth) { zoom = zoom > 1 ? 1 : 2.5 } }
                    .accessibilityLabel(scan.displayTitle)
            }
            CircleIconButton(symbol: "xmark", size: 40) { dismiss() }
                .padding(Spacing.lg)
                .accessibilityLabel("关闭")
        }
    }
}

/// 点了「太简单」后的几秒撤销条
private struct UndoBar: View {
    var word: String
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.onInk.opacity(0.8))
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: word)
                    .font(.word(16, weight: .bold))
                    .foregroundStyle(Theme.onInk)
                Text("已移出复习")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.onInk.opacity(0.7))
            }
            .lineLimit(1)
            Spacer(minLength: Spacing.xs)
            Button(action: onUndo) {
                Text("撤销")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Theme.onInk, in: .capsule)
            }
            .buttonStyle(.pressable)
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .background(Theme.ink, in: .capsule)
        .softShadow()
        .accessibilityElement(children: .contain)
    }
}

private struct RatingButton: View {
    var rating: ReviewRating
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(rating.mascot)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 58)
                    .padding(.bottom, 6)
                Text(rating.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text(rating.buttonHint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(rating.pastel, in: .rect(cornerRadius: Radius.card - 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card - 2, style: .continuous)
                    .strokeBorder(rating.tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(rating.title)，\(rating.buttonHint)")
    }
}

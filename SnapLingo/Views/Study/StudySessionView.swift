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
                .opacity(0.9)
                .animation(.easeInOut(duration: 0.6), value: session?.current?.id)
            if let session {
                if session.isFinished {
                    SessionCompleteView(session: session, onMore: { learnMore() }, onDone: { finish() })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    StudyCardsView(session: session, onClose: { finish() })
                        .transition(.opacity)
                }
            }
        }
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

    @ViewBuilder
    private var controls: some View {
        if session.revealed {
            HStack(spacing: Spacing.xs) {
                ForEach(ReviewRating.allCases) { rating in
                    RatingButton(rating: rating, interval: session.previewInterval(for: rating)) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            session.rate(rating, context: context)
                        }
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            PrimaryButton(title: "看看意思", symbol: "eye.fill") { reveal() }
                .transition(.opacity)
        }
    }

    private func reveal() {
        guard !session.revealed else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            session.revealed = true
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

    var body: some View {
        let word = card.word
        VStack(spacing: 0) {
            if let scan = word.latestScan {
                WordInPhotoView(word: word, scan: scan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text("\(scan.scene.emoji) \(scan.displayTitle)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 7)
                            .background(Theme.card, in: .capsule)
                            .softShadow()
                            .padding(Spacing.sm)
                    }
                    .padding(10)
                    .accessibilityLabel("在「\(scan.displayTitle)」里看到的词")
            }

            Spacer(minLength: Spacing.md)

            VStack(spacing: Spacing.sm) {
                Pill(
                    text: card.isNew
                        ? String(localized: "card.tag.new", defaultValue: "新词", comment: "Tag on a single flashcard: this is a new word (singular)")
                        : (card.attempt > 0 ? String(localized: "再试一次") : (card.isPractice ? String(localized: "再看一遍") : String(localized: "复习"))),
                    emoji: card.isNew ? "✨" : "🔁",
                    style: .tinted(card.isNew ? Theme.brandSoft : Pastel.lavender)
                )
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

            Text(card.isNew ? "第一次见？猜猜它是什么意思 🤔" : "还记得它的意思吗？")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.lg)
        }
    }
}

// MARK: - 背面

private struct CardBack: View {
    let word: VocabWord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                WordHeader(word: word, compact: true)

                Text(word.explanationStatus == .ready ? word.explanation : (word.gloss.isEmpty ? String(localized: "解释还在生成中，先凭印象评分吧") : word.gloss))
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

private struct RatingButton: View {
    var rating: ReviewRating
    var interval: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(rating.emoji)
                    .font(.system(size: 28))
                Text(rating.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Text(intervalText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(rating.pastel, in: .rect(cornerRadius: Radius.card - 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card - 2, style: .continuous)
                    .strokeBorder(rating.tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(rating.title)，\(intervalText)")
    }

    private var intervalText: String {
        guard let interval else {
            return rating == .again ? String(localized: "再看一遍") : String(localized: "本轮练习", comment: "Rating button subtitle: practice only, schedule unchanged")
        }
        if rating == .again { return String(localized: "稍后再来", comment: "Rating button subtitle: see it again later in this session") }
        switch interval {
        case 1: return String(localized: "明天")
        case 2..<14: return String(localized: "\(interval) 天后", comment: "Rating button subtitle: next review in N days")
        case 14..<60: return String(localized: "\(interval / 7) 周后", comment: "Rating button subtitle: next review in N weeks")
        default: return String(localized: "\(interval / 30) 个月后", comment: "Rating button subtitle: next review in N months")
        }
    }
}

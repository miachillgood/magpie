//
//  WordDetailView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

struct WordDetailView: View {
    @Bindable var word: VocabWord
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReviewLog.reviewedAt, order: .reverse) private var allLogs: [ReviewLog]
    @State private var confirmingDelete = false
    @State private var showingConsent = false

    private var logs: [ReviewLog] { allLogs.filter { $0.wordID == word.id } }
    private var scans: [Scan] { word.scans.sorted { $0.createdAt > $1.createdAt } }
    private var scene: SceneType { word.latestScan?.scene ?? .general }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                hero
                ExplanationCard(word: word, onEnableAI: { showingConsent = true }) {
                    word.explanationStatus = .pending
                    try? context.save()
                    ExplanationQueue.shared.run(context: context)
                }
                if !scans.isEmpty {
                    seenIn
                }
                progressCard
                actions
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 40)
        }
        .background(alignment: .top) {
            scene.pastel
                .frame(height: 360)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        }
        .background(PaperBackground())
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet()
        }
        .confirmationDialog("从词库删除“\(word.word)”？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                let target = word
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    WordLibrary.delete(target, context: context)
                }
            }
        }
    }

    // MARK: - 头部

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Pill(text: scene.displayName, emoji: scene.emoji, style: .tinted(Theme.card))
                Pill(text: word.state.displayName, emoji: word.state.emoji, style: .tinted(Theme.card))
                Spacer()
            }
            WordHeader(word: word)
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - 出现过的场景

    private var seenIn: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "你在这些地方见过它", emoji: "📍")
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.sm) {
                    ForEach(scans) { scan in
                        NavigationLink(value: scan) {
                            SceneCard(scan: scan, photoHeight: 120)
                                .frame(width: 180)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - 学习进度

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(verbatim: "\(word.state.emoji) \(word.state.displayName)")
                    .font(.headline.weight(.heavy))
                Spacer()
                Text(nextReviewText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if !logs.isEmpty {
                HStack(spacing: Spacing.sm) {
                    stat("\(logs.count)", "复习次数", Pastel.sky)
                    stat("\(logs.filter { $0.rating.isSuccess }.count * 100 / max(logs.count, 1))%", "记住率", Pastel.mint)
                    stat(String(localized: "\(word.intervalDays) 天", comment: "Current review interval in days"), "当前间隔", Pastel.lavender)
                }
                HStack(spacing: 4) {
                    ForEach(logs.prefix(14).reversed()) { log in
                        Text(log.rating.emoji)
                            .font(.caption)
                            .accessibilityLabel(log.rating.title)
                    }
                }
            }
        }
        .card(padding: Spacing.lg)
    }

    private func stat(_ value: String, _ label: LocalizedStringKey, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.weight(.heavy).monospacedDigit())
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink.opacity(0.6))
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: .rect(cornerRadius: Radius.small, style: .continuous))
    }

    private var nextReviewText: String {
        if word.excludedFromReview { return String(localized: "不再复习") }
        switch word.state {
        case .new: return String(localized: "还没开始学")
        default:
            let today = Calendar.current.startOfDay(for: Date())
            if word.dueDate <= today { return String(localized: "今天复习") }
            let relative = word.dueDate.formatted(.relative(presentation: .named))
            return String(localized: "下次 \(relative)", comment: "Next review, e.g. 'Next: in 3 days'")
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            SecondaryButton(
                title: word.excludedFromReview ? "恢复复习" : "我已经掌握了",
                symbol: word.excludedFromReview ? "arrow.uturn.backward" : "checkmark.seal"
            ) {
                WordLibrary.setMastered(word, !word.excludedFromReview, context: context)
            }
            .sensoryFeedback(.success, trigger: word.excludedFromReview)

            Button("从词库删除", role: .destructive) {
                confirmingDelete = true
            }
            .font(.subheadline.weight(.semibold))
            .padding(.top, Spacing.xs)
        }
        .padding(.top, Spacing.xs)
    }
}

// MARK: - 单词头部（学习卡片也会复用）

struct WordHeader: View {
    var word: VocabWord
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(word.word)
                    .font(compact ? .wordTitle : .wordHero)
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                HStack(spacing: Spacing.xs) {
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech)
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            SpeakButton(text: word.word)
        }
    }
}

struct SpeakButton: View {
    var text: String
    var size: CGFloat = 54
    private var speech = SpeechService.shared

    init(text: String, size: CGFloat = 54) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Button {
            speech.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.36, weight: .bold))
                .symbolEffect(.variableColor.iterative, isActive: speech.isSpeaking(text))
                .foregroundStyle(size > 40 ? Theme.onInk : Theme.ink)
                .frame(width: size, height: size)
                .background(size > 40 ? Theme.ink : Theme.insetFill, in: .circle)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: speech.speakingText)
        .accessibilityLabel("朗读 \(text)")
    }
}

// MARK: - 解释卡片

struct ExplanationCard: View {
    var word: VocabWord
    var onEnableAI: () -> Void
    var onRetry: () -> Void

    @AppStorage(AIConsent.storageKey) private var consentRaw = AIConsent.State.undecided.rawValue
    private var aiOn: Bool { consentRaw == AIConsent.State.granted.rawValue }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if word.explanationStatus != .ready && !aiOn {
                if !word.gloss.isEmpty {
                    Text(word.gloss).font(.title3.weight(.semibold))
                }
                HStack {
                    Text("AI 释义已关闭")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("打开", action: onEnableAI)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.brand)
                }
            } else {
                switch word.explanationStatus {
                case .ready:
                    block(title: "释义", emoji: "📖") {
                        Text(word.explanation)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    if !word.exampleSentence.isEmpty {
                        block(title: "例句", emoji: "💬") {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HighlightedText(text: word.exampleSentence, highlight: word.word)
                                        .font(.word(18, weight: .medium))
                                    Text(word.exampleTranslation)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                SpeakButton(text: word.exampleSentence, size: 36)
                            }
                            .padding(Spacing.md)
                            .background(Theme.insetFill, in: .rect(cornerRadius: Radius.small, style: .continuous))
                        }
                    }
                    if !word.sceneNote.isEmpty {
                        block(title: "生活小贴士", emoji: "💡") {
                            Text(word.sceneNote)
                                .font(.subheadline)
                                .padding(Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Pastel.butter, in: .rect(cornerRadius: Radius.small, style: .continuous))
                        }
                    }
                case .pending:
                    if !word.gloss.isEmpty {
                        Text(word.gloss).font(.title3.weight(.semibold))
                    }
                    Label("正在生成详细解释…", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse)
                case .failed:
                    if !word.gloss.isEmpty {
                        Text(word.gloss).font(.title3.weight(.semibold))
                    }
                    HStack {
                        Text("😕 解释生成失败")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("重试", action: onRetry)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.brand)
                    }
                }
            }

            if !word.contextSnippet.isEmpty {
                block(title: "在照片里", emoji: "📷") {
                    HighlightedText(text: word.contextSnippet, highlight: word.word)
                        .font(.word(16, weight: .regular))
                }
            }
        }
        .card(padding: Spacing.lg, radius: Radius.hero)
    }

    private func block<Content: View>(title: LocalizedStringKey, emoji: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 4) { Text(verbatim: emoji); Text(title) }
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// 把语境里的目标词高亮
struct HighlightedText: View {
    var text: String
    var highlight: String

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        let target = highlight.lowercased()
        guard !target.isEmpty else { return result }
        var searchStart = result.startIndex
        while let range = result[searchStart...].range(of: target, options: .caseInsensitive) {
            result[range].foregroundColor = Theme.brand
            result[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
        return result
    }
}

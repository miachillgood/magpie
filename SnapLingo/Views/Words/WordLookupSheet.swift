//
//  WordLookupSheet.swift
//  SnapLingo
//
//  在词库里搜一个还没收的词：先看释义，再决定要不要加入复习。
//  释义用的是保存后生成解释的同一个接口（explainWords），所以加进来就是完整的学习卡，不用再等。
//  没同意用 AI 也能加：先只存单词，等以后打开 AI 再由 ExplanationQueue 补上释义。
//

import SwiftUI
import SwiftData

struct WordLookupSheet: View {
    var query: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var phase: Phase = .loading
    @State private var existing: VocabWord?
    @State private var added = false
    @State private var showingConsent = false

    private enum Phase {
        case loading
        case loaded(WordExplanation)
        /// 没同意用 AI：只能看到单词本身
        case noAI
        case failed(String)
    }

    /// 像一个英文词或短语才给「查一查」：只有字母、空格、' 和 -，最多 4 个词
    nonisolated static func isLookupQuery(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: \.isASCIILetter) else { return false }
        let allowed = trimmed.allSatisfy { $0.isASCIILetter || $0 == " " || $0 == "'" || $0 == "’" || $0 == "-" }
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        return allowed && words.count <= 4
    }

    private var word: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                switch phase {
                case .loading:
                    loadingCard
                case .loaded(let explanation):
                    meaningCard(explanation)
                case .noAI:
                    note(Text("AI 功能没打开，先只保存单词，释义以后补上。"), symbol: "sparkles")
                case .failed(let message):
                    note(Text(verbatim: message), symbol: "exclamationmark.triangle")
                    Button("重试") { Task { await load() } }
                        .font(.subheadline.weight(.semibold))
                        .tint(Theme.homeInk)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background(Theme.cream.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .sensoryFeedback(.success, trigger: added)
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet { Task { await load() } }
        }
        .task {
            if AIConsent.state == .undecided {
                showingConsent = true
            } else {
                await load()
            }
        }
    }

    // MARK: - 内容

    private var displayWord: String {
        if case .loaded(let explanation) = phase, !explanation.lemma.isEmpty,
           explanation.lemma.normalizedWordKey != word.normalizedWordKey {
            return explanation.lemma
        }
        return word
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: displayWord)
                    .font(.wordHero)
                    .foregroundStyle(Theme.homeInk)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                if case .loaded(let explanation) = phase {
                    HStack(spacing: Spacing.xs) {
                        if !explanation.phonetic.isEmpty {
                            Text(verbatim: explanation.phonetic)
                                .font(.subheadline.weight(.medium))
                        }
                        if !explanation.partOfSpeech.isEmpty {
                            Text(verbatim: explanation.partOfSpeech)
                                .font(.subheadline.italic())
                        }
                        if let cefr = explanation.cefr {
                            Text(verbatim: cefr.code)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.homeInk.opacity(0.08), in: .capsule)
                        }
                    }
                    .foregroundStyle(Theme.homeMuted)
                }
            }
            Spacer(minLength: 0)
            SpeakButton(text: displayWord)
        }
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([0.5, 0.9, 0.7], id: \.self) { width in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.homeInk.opacity(0.08))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: width, anchor: .leading)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 20, style: .continuous))
        .phaseAnimator([0.5, 1]) { content, opacity in
            content.opacity(opacity)
        } animation: { _ in .easeInOut(duration: 0.8) }
        .accessibilityLabel("正在查")
    }

    private func meaningCard(_ explanation: WordExplanation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !explanation.gloss.isEmpty {
                Text(verbatim: explanation.gloss)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.homeInk)
            }
            if !explanation.explanation.isEmpty, explanation.explanation != explanation.gloss {
                Text(verbatim: explanation.explanation)
                    .font(.body)
                    .foregroundStyle(Theme.homeInk.opacity(0.85))
            }
            if !explanation.exampleSentence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: explanation.exampleSentence)
                        .font(.body.italic())
                        .foregroundStyle(Theme.homeInk)
                    if !explanation.exampleTranslation.isEmpty {
                        Text(verbatim: explanation.exampleTranslation)
                            .font(.subheadline)
                            .foregroundStyle(Theme.homeMuted)
                    }
                }
                .padding(.top, 4)
            }
            if !explanation.sceneNote.isEmpty {
                Text(verbatim: "💡 \(explanation.sceneNote)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.homeInk.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func note(_ text: Text, symbol: String) -> some View {
        Label {
            text
        } icon: {
            Image(systemName: symbol)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.homeMuted)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sheet, in: .rect(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 底部按钮

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if let existing {
                PrimaryButton(title: "已在词库 · 查看", trailingSymbol: "arrow.right") {
                    dismiss()
                    coordinator.openWordID = existing.id
                }
            } else if added {
                Label("已加入复习", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.homeInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                PrimaryButton(title: "加入复习", symbol: "plus") { add() }
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.4 : 1)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
        .background(Theme.cream)
    }

    private var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    // MARK: - 动作

    private func load() async {
        existing = find(word.normalizedWordKey)
        guard AIConsent.isGranted else {
            phase = .noAI
            return
        }
        phase = .loading
        let key = word.normalizedWordKey
        do {
            let language = UserSettings.current(in: context).nativeLanguage
            let results = try await ClaudeAPIService.shared.explainWords(
                [ExplainItem(key: key, word: word, context: "")],
                scene: .general,
                language: language
            )
            guard let explanation = results[key] ?? results.values.first else {
                phase = .failed(ClaudeAPIError.decoding.errorDescription ?? "")
                return
            }
            // 搜的是 oats、词库里存的是 oat：按原形再找一次
            if existing == nil { existing = find(explanation.lemma.normalizedWordKey) }
            withAnimation(.snappy) { phase = .loaded(explanation) }
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func find(_ key: String) -> VocabWord? {
        guard !key.isEmpty else { return nil }
        let descriptor = FetchDescriptor<VocabWord>(predicate: #Predicate { $0.normalizedForm == key })
        return try? context.fetch(descriptor).first
    }

    private func add() {
        var explanation: WordExplanation?
        if case .loaded(let loaded) = phase { explanation = loaded }
        let candidate = WordCandidate(
            word: word,
            lemma: explanation?.lemma ?? "",
            partOfSpeech: explanation?.partOfSpeech ?? "",
            cefrRaw: explanation?.cefr?.rawValue ?? 0,
            gloss: explanation?.gloss ?? ""
        )
        WordLibrary.addStandalone(candidate, explanation: explanation, context: context)
        if explanation == nil { ExplanationQueue.shared.run(context: context) }
        StudyReminder.refresh(context: context)
        withAnimation(.snappy) { added = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            dismiss()
        }
    }
}

private extension Character {
    nonisolated var isASCIILetter: Bool { isASCII && isLetter }
}

//
//  WordPickerView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 选词页：照片上点词 + 按水平分组的推荐列表
struct WordPickerView: View {
    private enum Mode {
        case new(WordLibrary.ScanDraft)
        case existing(Scan)
    }

    private let mode: Mode
    private let onRetake: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    @State private var candidates: [WordCandidate] = []
    @State private var classified: [ClassifiedCandidate] = []
    @State private var selected: Set<String> = []
    @State private var tokenMap: [Int: String] = [:]
    @State private var savedKeys: Set<String> = []
    @State private var title = ""
    @State private var scene: SceneType = .general
    @State private var level: CEFRLevel = .b1
    @State private var prepared = false
    @State private var savedCount: Int?

    init(draft: WordLibrary.ScanDraft, onRetake: @escaping () -> Void) {
        self.mode = .new(draft)
        self.onRetake = onRetake
    }

    init(existingScan: Scan) {
        self.mode = .existing(existingScan)
        self.onRetake = nil
    }

    private var isNewScan: Bool {
        if case .new = mode { return true }
        return false
    }

    private var image: UIImage? {
        switch mode {
        case .new(let draft): draft.image
        case .existing(let scan): scan.fullImage
        }
    }

    private var tokens: [OCRToken] {
        switch mode {
        case .new(let draft): draft.ocr.tokens
        case .existing(let scan): scan.tokens
        }
    }

    private var aiError: String? {
        if case .new(let draft) = mode { return draft.aiError }
        return nil
    }

    private var newSelectionCount: Int {
        selected.subtracting(savedKeys).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                photo
                if let aiError {
                    Text("😕 \(aiError)。你可以直接点照片上的词来添加。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .card()
                }
                if isNewScan {
                    sceneCard
                }
                ForEach(CandidateGroup.allCases) { group in
                    let items = classified.filter { $0.group == group }
                    if !items.isEmpty {
                        groupSection(group, items: items)
                    }
                }
                if prepared && classified.isEmpty && aiError == nil {
                    ContentUnavailableView("没有挑出单词", systemImage: "text.magnifyingglass", description: Text("点照片上的词，把想学的加进来。"))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(PaperBackground())
        .safeAreaBar(edge: .bottom) { bottomBar }
        .navigationTitle(isNewScan ? "选词" : "再选几个词")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .overlay {
            if let savedCount {
                SavedHUD(count: savedCount)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.success, trigger: savedCount) { _, new in new != nil }
        .task { prepare() }
    }

    // MARK: - 照片

    @ViewBuilder
    private var photo: some View {
        if let image {
            PhotoWordOverlay(image: image, tokens: tokens, highlight: highlight, onTap: tap)
                .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
                .padding(8)
                .background(Theme.card, in: .rect(cornerRadius: Radius.hero, style: .continuous))
                .softShadow()
                .overlay(alignment: .bottomLeading) {
                    if !tokens.isEmpty {
                        Text("👆 点照片上的词也能加入")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 7)
                            .background(Theme.card, in: .capsule)
                            .softShadow()
                            .padding(Spacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xs)
        }
    }

    private var sceneCard: some View {
        HStack(spacing: Spacing.sm) {
            Menu {
                Picker("场景类型", selection: $scene) {
                    ForEach(SceneType.allCases) { scene in
                        Text("\(scene.emoji) \(scene.displayName)").tag(scene)
                    }
                }
            } label: {
                EmojiTile(emoji: scene.emoji, color: scene.pastel, size: 52)
            }
            .accessibilityLabel("场景类型：\(scene.displayName)")
            VStack(alignment: .leading, spacing: 4) {
                TextField("给这个场景起个名字", text: $title)
                    .font(.title3.weight(.heavy))
                    .submitLabel(.done)
                HStack(spacing: 6) {
                    Text(scene.displayName)
                    Text("·")
                    Text("你的水平 \(level.code)")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            }
        }
        .card(padding: Spacing.sm + 2)
    }

    // MARK: - 分组

    private func groupSection(_ group: CandidateGroup, items: [ClassifiedCandidate]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: group.title, emoji: group.emoji, subtitle: subtitle(for: group)) {
                if group == .recommended || group == .advanced || group == .known {
                    let keys = Set(items.map(\.id))
                    let allOn = keys.isSubset(of: selected)
                    Button(allOn ? "全不选" : "全选") {
                        withAnimation(.snappy) {
                            if allOn { selected.subtract(keys) } else { selected.formUnion(keys) }
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.brand)
                }
            }
            FlowLayout(spacing: Spacing.xs) {
                ForEach(items) { item in
                    CandidateChip(
                        candidate: item.candidate,
                        isSelected: selected.contains(item.id),
                        isSaved: group == .saved
                    ) {
                        toggle(item.id)
                    }
                }
            }
        }
    }

    private func subtitle(for group: CandidateGroup) -> String {
        switch group {
        case .recommended:
            let upper = level.next.map { "–\($0.code)" } ?? ""
            return "\(level.code)\(upper) 难度，现在学正合适"
        case .advanced: return "比你现在的水平难一些"
        case .known: return "取消勾选会让推荐更懂你"
        case .saved: return "会把这个场景加到它们的记忆里"
        }
    }

    // MARK: - 底栏

    private var bottomBar: some View {
        VStack(spacing: 6) {
            PrimaryButton(title: saveTitle, symbol: "checkmark") { save() }
                .disabled(!prepared || savedCount != nil || (!isNewScan && newSelectionCount == 0))
            Text("新词会先放进待学，按每日计划慢慢学")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }

    private var saveTitle: String {
        if newSelectionCount == 0 { return isNewScan ? "只保存场景" : "选择要加入的词" }
        return "保存 \(newSelectionCount) 个词"
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let onRetake {
            ToolbarItem(placement: .topBarLeading) {
                Button("重拍", systemImage: "arrow.counterclockwise", action: onRetake)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭", systemImage: "xmark") { coordinator.showingScan = false }
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    // MARK: - 逻辑

    private func prepare() {
        guard !prepared else { return }
        let settings = UserSettings.current(in: context)
        level = settings.level
        savedKeys = Set(StudyStore.words(context).map(\.normalizedForm))

        switch mode {
        case .new(let draft):
            candidates = draft.extraction?.candidates ?? []
            title = draft.extraction?.title ?? ""
            scene = draft.extraction?.scene ?? .general
        case .existing(let scan):
            candidates = scan.candidates
        }

        classified = LevelService.classify(
            candidates,
            level: level,
            familiarity: LevelService.familiarityMap(in: context),
            savedKeys: savedKeys
        )
        selected = Set(classified.filter(\.preselected).map(\.id))
        buildTokenMap()
        prepared = true
    }

    /// 照片上的每个词对应到哪个候选词
    private func buildTokenMap() {
        var surface: [String: String] = [:]
        for candidate in candidates {
            surface[candidate.key] = candidate.key
            surface[candidate.word.normalizedWordKey] = candidate.key
            // 词组的每个词也指向这个候选词（单独的同名候选词优先）
            for part in candidate.word.split(separator: " ") {
                let key = String(part).normalizedWordKey
                if surface[key] == nil { surface[key] = candidate.key }
            }
        }
        let lemmas = WordLibrary.lemmas(of: tokens.map(\.text))
        var map: [Int: String] = [:]
        for (token, lemma) in zip(tokens, lemmas) {
            if let key = surface[token.key] ?? surface[lemma] {
                map[token.id] = key
            } else if savedKeys.contains(lemma) {
                map[token.id] = lemma
            }
        }
        tokenMap = map
    }

    private func highlight(_ token: OCRToken) -> TokenHighlight {
        guard let key = tokenMap[token.id] else { return .none }
        if savedKeys.contains(key) { return .saved }
        return selected.contains(key) ? .selected : .candidate
    }

    private func toggle(_ key: String) {
        guard !savedKeys.contains(key) else { return }
        withAnimation(.snappy(duration: 0.2)) {
            if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
        }
    }

    private func tap(_ token: OCRToken) {
        if let key = tokenMap[token.id] {
            toggle(key)
            return
        }
        let lemma = WordLibrary.lemma(of: token.text)
        let candidate = WordCandidate(word: token.text, lemma: lemma, partOfSpeech: "", cefrRaw: 0, gloss: "", pickedFromPhoto: true)
        guard !candidate.key.isEmpty else { return }
        for other in tokens where other.key == token.key {
            tokenMap[other.id] = candidate.key
        }
        if classified.contains(where: { $0.id == candidate.key }) {
            toggle(candidate.key)
            return
        }
        withAnimation(.snappy) {
            candidates.append(candidate)
            classified.insert(ClassifiedCandidate(candidate: candidate, group: .recommended, preselected: true), at: 0)
            selected.insert(candidate.key)
        }
    }

    private func save() {
        let settings = UserSettings.current(in: context)
        // 已在词库的词：把这个场景也关联上，作为新的记忆线索
        let linkKeys = selected.union(classified.filter { $0.group == .saved }.map(\.id))
        let count = newSelectionCount

        switch mode {
        case .new(let draft):
            WordLibrary.saveNewScan(
                draft: draft,
                title: title,
                scene: scene,
                candidates: candidates,
                selectedKeys: linkKeys,
                context: context
            )
        case .existing(let scan):
            WordLibrary.addWords(candidates.filter { linkKeys.contains($0.key) }, to: scan, context: context)
            scan.candidates = candidates
        }

        LevelService.recordSelection(classified: classified, selectedKeys: selected, in: context)
        settings.levelScore = LevelService.clamp(
            settings.levelScore + LevelService.selectionDelta(classified: classified, selectedKeys: selected)
        )
        try? context.save()
        ExplanationQueue.shared.run(context: context)
        StudyReminder.refresh(context: context)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { savedCount = count }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            if isNewScan {
                coordinator.selectedTab = .home
                coordinator.showingScan = false
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - 候选词芯片

private struct CandidateChip: View {
    var candidate: WordCandidate
    var isSelected: Bool
    var isSaved: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // 图标宽度固定，选中时不会挤动其他芯片
                Image(systemName: isSaved ? "tray.full.fill" : (isSelected ? "checkmark.circle.fill" : "plus.circle"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected && !isSaved ? Color.white : Theme.ink.opacity(0.35))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 1) {
                    Text(candidate.displayWord)
                        .font(.word(17, weight: .bold))
                    if !candidate.gloss.isEmpty {
                        Text(candidate.gloss)
                            .font(.caption2.weight(.semibold))
                            .opacity(0.75)
                    } else if candidate.pickedFromPhoto {
                        Text("从照片点选")
                            .font(.caption2.weight(.semibold))
                            .opacity(0.75)
                    }
                }
                if let cefr = candidate.cefr {
                    Text(cefr.code)
                        .font(.caption2.weight(.heavy).monospaced())
                        .opacity(0.5)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected && !isSaved ? Color.white : Theme.ink)
            .background(background, in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected || isSaved ? .clear : Theme.hairline))
            .softShadow(isSelected && !isSaved ? 0.8 : 0.4)
            .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
        .disabled(isSaved)
        .opacity(isSaved ? 0.65 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSaved { return Theme.insetFill }
        return isSelected ? Theme.brand : Theme.card
    }
}

extension CandidateGroup {
    var emoji: String {
        switch self {
        case .recommended: "✨"
        case .advanced:    "🔥"
        case .known:       "👌"
        case .saved:       "📥"
        }
    }
}

// MARK: - 保存成功

private struct SavedHUD: View {
    var count: Int
    @State private var pop = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("🎉")
                .font(.system(size: 60))
                .scaleEffect(pop ? 1 : 0.4)
            Text(count > 0 ? "已保存 \(count) 个词" : "场景已保存")
                .font(.title3.weight(.heavy))
            Text(count > 0 ? "它们会出现在今日计划里" : "随时可以回来再选词")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.xl)
        .background(Theme.card, in: .rect(cornerRadius: Radius.hero, style: .continuous))
        .softShadow(2)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { pop = true }
        }
    }
}

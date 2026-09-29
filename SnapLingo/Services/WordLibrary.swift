//
//  WordLibrary.swift
//  SnapLingo
//

import Foundation
import NaturalLanguage
import SwiftData
import UIKit

/// 单词和场景的增删改（所有写操作都走这里，保证只有一份数据）
enum WordLibrary {

    // MARK: - 保存场景

    struct ScanDraft {
        var image: UIImage
        var ocr: OCRResult
        var extraction: SceneExtraction?
        /// AI 挑词失败时的提示（仍然可以在照片上点词）
        var aiError: String? = nil
    }

    /// 创建一个新场景并保存选中的词
    @discardableResult
    static func saveNewScan(
        draft: ScanDraft,
        title: String,
        scene: SceneType,
        candidates: [WordCandidate],
        selectedKeys: Set<String>,
        context: ModelContext
    ) -> Scan {
        let scan = Scan()
        scan.title = title
        scan.scene = scene
        scan.imageData = draft.image.jpegData(compressionQuality: 0.82)
        scan.thumbnailData = ImageUtilities.jpeg(draft.image, maxDimension: 600, quality: 0.75)
        scan.imageAspectRatio = draft.image.size.height > 0 ? Double(draft.image.size.width / draft.image.size.height) : 1
        scan.ocrText = draft.ocr.fullText
        scan.tokens = draft.ocr.tokens
        scan.lines = draft.ocr.lines
        scan.candidates = candidates
        context.insert(scan)

        addWords(candidates.filter { selectedKeys.contains($0.key) }, to: scan, context: context)
        try? context.save()
        return scan
    }

    /// 把候选词加入词库并关联到场景；已存在的词只补关联
    @discardableResult
    static func addWords(_ candidates: [WordCandidate], to scan: Scan, context: ModelContext) -> [VocabWord] {
        let existing = (try? context.fetch(FetchDescriptor<VocabWord>())) ?? []
        var byKey = Dictionary(existing.map { ($0.normalizedForm, $0) }, uniquingKeysWith: { first, _ in first })
        var touched: [VocabWord] = []

        for candidate in candidates {
            let key = candidate.key
            if let word = byKey[key] {
                if !word.scans.contains(where: { $0.id == scan.id }) {
                    word.scans.append(scan)
                }
                touched.append(word)
                continue
            }
            let word = VocabWord(
                word: candidate.displayWord,
                partOfSpeech: candidate.partOfSpeech,
                cefr: candidate.cefr,
                gloss: candidate.gloss,
                contextSnippet: contextLine(for: candidate, in: scan)
            )
            context.insert(word)
            word.scans.append(scan)
            byKey[key] = word
            touched.append(word)
        }
        return touched
    }

    /// 语境：优先找包含原文写法的那一行
    private static func contextLine(for candidate: WordCandidate, in scan: Scan) -> String {
        let surface = candidate.word.normalizedWordKey
        let lemma = candidate.key
        return scan.lines.first { $0.text.wordKeys.contains(surface) }?.text
            ?? scan.lines.first { $0.text.wordKeys.contains(lemma) }?.text
            ?? scan.lines.first { $0.text.lowercased().contains(surface) }?.text
            ?? ""
    }

    // MARK: - 删除

    /// 删除场景；只属于这个场景的词一起删除
    static func delete(_ scan: Scan, context: ModelContext) {
        let orphaned = scan.words.filter { $0.scans.count <= 1 }
        orphaned.forEach { context.delete($0) }
        context.delete(scan)
        try? context.save()
    }

    static func delete(_ word: VocabWord, context: ModelContext) {
        context.delete(word)
        try? context.save()
    }

    // MARK: - 状态

    static func setMastered(_ word: VocabWord, _ mastered: Bool, context: ModelContext) {
        word.excludedFromReview = mastered
        if mastered {
            word.state = .mastered
            LevelService.recordFamiliarity(key: word.normalizedForm, confidence: 0.95, source: .mastery, in: context)
        } else {
            word.state = word.introducedAt == nil ? .new : (word.intervalDays >= SpacedRepetition.masteredThreshold ? .mastered : .learning)
            word.dueDate = Calendar.current.startOfDay(for: Date())
        }
        try? context.save()
    }

    // MARK: - 词形还原

    /// 用 NaturalLanguage 取原形（照片上点选的词没有经过 Claude）
    nonisolated static func lemma(of word: String) -> String {
        lemmas(of: [word]).first ?? word.normalizedWordKey
    }

    /// 批量取原形（复用同一个 tagger）
    nonisolated static func lemmas(of words: [String]) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        return words.map { word in
            guard !word.isEmpty else { return "" }
            tagger.string = word
            let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma)
            let lemma = tag?.rawValue ?? ""
            return lemma.isEmpty ? word.normalizedWordKey : lemma.normalizedWordKey
        }
    }
}

// MARK: - 后台批量生成解释

/// 保存后在后台为新词生成解释，失败的下次自动重试
@Observable
final class ExplanationQueue {
    static let shared = ExplanationQueue()

    private(set) var isRunning = false
    private(set) var lastError: String?
    private let batchSize = 12

    func run(context: ModelContext) {
        guard !isRunning else { return }
        isRunning = true
        Task {
            await process(context: context)
            isRunning = false
        }
    }

    private func process(context: ModelContext) async {

        let readyRaw = ExplanationStatus.ready.rawValue
        let descriptor = FetchDescriptor<VocabWord>(predicate: #Predicate { $0.explanationStatusRaw != readyRaw })
        let pending = (try? context.fetch(descriptor)) ?? []
        guard !pending.isEmpty else { return }

        // 按场景分组，让解释贴合场景
        let groups = Dictionary(grouping: pending) { $0.latestScan?.scene ?? .general }
        lastError = nil

        for (scene, words) in groups {
            for chunk in stride(from: 0, to: words.count, by: batchSize).map({ Array(words[$0..<min($0 + batchSize, words.count)]) }) {
                let items = chunk.map { ExplainItem(key: $0.normalizedForm, word: $0.word, context: $0.contextSnippet) }
                do {
                    let results = try await ClaudeAPIService.shared.explainWords(items, scene: scene)
                    for word in chunk {
                        guard let exp = results[word.normalizedForm] else {
                            word.explanationStatus = .failed
                            continue
                        }
                        word.applyExplanation(exp)
                        if word.gloss.isEmpty { word.gloss = exp.gloss }
                        if word.cefrRaw == 0, let level = exp.cefr { word.cefrRaw = level.rawValue }
                        if word.partOfSpeech.isEmpty { word.partOfSpeech = exp.partOfSpeech }
                    }
                } catch {
                    chunk.forEach { $0.explanationStatus = .failed }
                    lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
                try? context.save()
            }
        }
    }
}

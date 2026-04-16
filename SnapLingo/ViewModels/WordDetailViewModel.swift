//
//  WordDetailViewModel.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

@Observable
final class WordDetailViewModel {

    // MARK: - 状态

    var explanations: [String: WordExplanation] = [:]
    var loadingStates: [String: Bool] = [:]
    var errors: [String: String] = [:]
    var savedWords: Set<String> = []

    // MARK: - 依赖

    private let claudeService = ClaudeAPIService()

    // MARK: - 并发加载所有解释

    func loadAll(words: [String], ocrText: String, scene: SceneTag) async {
        // 初始化 loading 状态
        await MainActor.run {
            for w in words { loadingStates[w] = true }
        }

        await withTaskGroup(of: (String, Result<WordExplanation, Error>).self) { group in
            for word in words {
                group.addTask {
                    do {
                        let exp = try await self.claudeService.generateExplanation(
                            for: word, context: ocrText, scene: scene
                        )
                        return (word, .success(exp))
                    } catch {
                        return (word, .failure(error))
                    }
                }
            }
            for await (word, result) in group {
                await MainActor.run {
                    loadingStates[word] = false
                    switch result {
                    case .success(let exp): explanations[word] = exp
                    case .failure(let e):   errors[word] = e.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - 保存词汇

    func save(word: String, scene: SceneTag, categoryName: String, sourceImage: UIImage?, scanSessionID: UUID, context: ModelContext) {
        guard let exp = explanations[word] else { return }

        // 去重检查
        let normalized = word.lowercased().trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<VocabWord>(
            predicate: #Predicate { $0.normalizedForm == normalized }
        )
        if (try? context.fetch(descriptor))?.isEmpty == false {
            savedWords.insert(word)
            return
        }

        let vocab = VocabWord(
            word: word,
            chineseExplanation: exp.chineseExplanation,
            exampleSentence: exp.exampleSentence,
            exampleSentenceChinese: exp.exampleSentenceChinese,
            sceneNote: exp.sceneNote,
            sceneTag: scene,
            scanSessionID: scanSessionID,
            categoryName: categoryName
        )
        if let img = sourceImage {
            vocab.sourceImageThumbnail = ImageUtilities.thumbnail(from: img)
        }
        context.insert(vocab)
        savedWords.insert(word)
    }

    func isSaved(_ word: String) -> Bool { savedWords.contains(word) }
    func isLoading(_ word: String) -> Bool { loadingStates[word] == true }
}

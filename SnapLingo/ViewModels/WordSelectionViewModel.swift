//
//  WordSelectionViewModel.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

@Observable
final class WordSelectionViewModel {

    // MARK: - 状态

    var presentedWords: [ExtractedWord] = []
    var selectedWordTexts: Set<String> = []
    var detectedScene: SceneTag = .general
    var editableCategory: String = "通用"   // 用户可编辑的分类名
    var isLoadingKeywords = false
    var errorMessage: String?

    // MARK: - 依赖

    private let claudeService = ClaudeAPIService()

    // MARK: - 加载关键词

    func loadKeywords(from ocrText: String, userLevel: UserLevel) async {
        await MainActor.run {
            isLoadingKeywords = true
            errorMessage = nil
            presentedWords = []
        }

        do {
            let result = try await claudeService.extractKeywords(
                from: ocrText,
                userLevel: userLevel
            )
            await MainActor.run {
                presentedWords = result.words
                detectedScene = result.detectedScene
                editableCategory = result.suggestedCategory
                // 首次拍照（水平未知）：预选 Claude 认为可能不认识的词，降低操作摩擦
                if userLevel == .unknown {
                    selectedWordTexts = Set(result.words.filter { !$0.likelyKnown }.map(\.word))
                }
                isLoadingKeywords = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoadingKeywords = false
            }
        }
    }

    // MARK: - 选词交互

    func toggle(_ word: String) {
        if selectedWordTexts.contains(word) {
            selectedWordTexts.remove(word)
        } else {
            selectedWordTexts.insert(word)
        }
    }

    var isSelected: (String) -> Bool {
        { [weak self] word in self?.selectedWordTexts.contains(word) ?? false }
    }

    var canConfirm: Bool { !selectedWordTexts.isEmpty }

    // MARK: - 水平评估（首次拍照时调用）

    /// 根据选词比例推断用户水平
    func estimatedLevel() -> UserLevel {
        guard !presentedWords.isEmpty else { return .unknown }
        let ratio = Double(selectedWordTexts.count) / Double(presentedWords.count)
        switch ratio {
        case ..<0.3:  return .advanced
        case 0.3..<0.7: return .intermediate
        default:      return .beginner
        }
    }
}

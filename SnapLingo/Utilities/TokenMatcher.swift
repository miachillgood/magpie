//
//  TokenMatcher.swift
//  SnapLingo
//

import Foundation

/// 在照片的 OCR 单词框里找到某个词（或词组）的位置，兼容复数、时态等词形变化
struct TokenMatcher {
    private let tokens: [OCRToken]
    private let lemmas: [Int: String]

    init(tokens: [OCRToken]) {
        let ordered = tokens.sorted { $0.id < $1.id }
        self.tokens = ordered
        let computed = WordLibrary.lemmas(of: ordered.map(\.text))
        self.lemmas = Dictionary(uniqueKeysWithValues: zip(ordered.map(\.id), computed))
    }

    /// 这个词在照片里出现的所有位置（每个位置是一组连续的单词框）
    func occurrences(of word: String, preferLine lineIndex: Int? = nil) -> [[OCRToken]] {
        let parts = word.split(separator: " ").map { String($0).normalizedWordKey }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return [] }

        var results: [[OCRToken]] = []
        for start in tokens.indices {
            guard matches(tokens[start], parts[0]) else { continue }
            var group = [tokens[start]]
            var index = start
            for part in parts.dropFirst() {
                index += 1
                guard index < tokens.count,
                      tokens[index].lineIndex == tokens[start].lineIndex || tokens[index].lineIndex == tokens[index - 1].lineIndex + 1,
                      matches(tokens[index], part) else { group = []; break }
                group.append(tokens[index])
            }
            if !group.isEmpty { results.append(group) }
        }
        if let lineIndex {
            results.sort { lhs, rhs in
                (lhs.first?.lineIndex == lineIndex ? 0 : 1) < (rhs.first?.lineIndex == lineIndex ? 0 : 1)
            }
        }
        return results
    }

    /// 多个词在照片里命中的单词框 id
    func tokenIDs(for words: [String]) -> Set<Int> {
        Set(words.flatMap { occurrences(of: $0).flatMap { $0.map(\.id) } })
    }

    private func matches(_ token: OCRToken, _ part: String) -> Bool {
        let key = token.key
        if key == part || lemmas[token.id] == part { return true }
        // 简单的复数兜底（NaturalLanguage 对孤立单词偶尔还原失败）
        if key.hasSuffix("es"), String(key.dropLast(2)) == part { return true }
        if key.hasSuffix("s"), String(key.dropLast()) == part { return true }
        return false
    }
}

//
//  ClaudeAPIService.swift
//  SnapLingo
//

import Foundation

// MARK: - 请求 / 响应结构体

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

private struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Decodable {
    struct ContentBlock: Decodable { let type: String; let text: String }
    struct Usage: Decodable { let input_tokens: Int; let output_tokens: Int }
    let content: [ContentBlock]
    let usage: Usage
}

// MARK: - 业务数据结构

struct ExtractedWord: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let likelyKnown: Bool   // Claude 认为该用户水平大概率认识
}

struct KeywordExtractionResult {
    let words: [ExtractedWord]
    let detectedScene: SceneTag
}

struct WordExplanation {
    let chineseExplanation: String
    let exampleSentence: String
    let exampleSentenceChinese: String
    let sceneNote: String
}

// MARK: - 错误类型

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case unauthorized
    case rateLimited
    case networkError(Error)
    case decodingError(String)
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:          return "请先在设置中填写 Claude API Key"
        case .unauthorized:      return "API Key 无效，请重新检查"
        case .rateLimited:       return "请求过于频繁，请稍候再试"
        case .networkError(let e): return "网络错误：\(e.localizedDescription)"
        case .decodingError(let s): return "数据解析失败：\(s)"
        case .apiError(let code, let msg): return "API 错误 \(code)：\(msg)"
        }
    }
}

// MARK: - ClaudeAPIService

final class ClaudeAPIService {
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model   = "claude-haiku-4-5-20251001"

    // MARK: - 筛词（Prompt A）

    func extractKeywords(
        from text: String,
        userLevel: UserLevel = .unknown,
        sceneHint: SceneTag? = nil
    ) async throws -> KeywordExtractionResult {

        let systemPrompt = """
        你是一个专业的英语教学助手，帮助中文母语者学习英语。
        用户当前英语水平：\(userLevel.displayName)
        \(sceneHint.map { "当前场景提示：\($0.rawValue)" } ?? "")

        你的任务是从OCR识别的英文文本中筛选出最有学习价值的词汇。
        筛选标准：
        1. 选择对该场景重要的专业词汇或实用词汇
        2. 选择该水平学习者可能不认识的词，排除极其常见的基础词（the, is, a, and, to, of 等）
        3. 排除纯数字、纯符号、单个字母
        4. 每次返回 10-15 个词（文本词汇不足时返回全部有价值的词）

        只返回 JSON，不要有任何多余文字或 markdown 代码块：
        {"scene_detected":"restaurant|supermarket|medical|legal|signage|general","words":[{"word":"prescription","likely_known":false}]}
        """

        let userMessage = "请从以下英文文本中提取关键学习词汇：\n\n\(text)"

        let raw = try await callClaude(system: systemPrompt, user: userMessage, maxTokens: 1024)

        // 解析 JSON
        struct RawWord: Decodable { let word: String; let likely_known: Bool }
        struct RawResult: Decodable { let scene_detected: String; let words: [RawWord] }

        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let result = try? JSONDecoder().decode(RawResult.self, from: data) else {
            throw ClaudeAPIError.decodingError(raw)
        }

        let scene = SceneTag(rawValue: result.scene_detected) ?? .general
        let words = result.words.map { ExtractedWord(word: $0.word, likelyKnown: $0.likely_known) }
        return KeywordExtractionResult(words: words, detectedScene: scene)
    }

    // MARK: - 生成解释（Prompt B）

    func generateExplanation(
        for word: String,
        context: String,
        scene: SceneTag
    ) async throws -> WordExplanation {

        let systemPrompt = """
        你是一个专业的英语词汇教学助手，专门为中文母语者提供清晰、实用的英语词汇解释。
        你的解释必须：
        1. 用中文解释，简洁易懂（不超过 30 字）
        2. 结合实际场景（\(scene.rawValue)）
        3. 提供一个真实场景中的简短英文例句（不超过 15 个单词）
        4. 避免使用复杂语法术语

        只返回 JSON，不要有任何多余文字或 markdown 代码块：
        {"chinese_explanation":"处方；医生开具的药方","example_sentence":"Please bring your prescription to the pharmacy.","example_sentence_chinese":"请把您的处方带到药房。","scene_note":"在药店或医院常见，凭此配药。"}
        """

        // 截取词汇上下文（前后 60 字符）
        let snippet = contextSnippet(for: word, in: context)
        let userMessage = """
        请解释这个英语单词：\(word)

        这个词出现在以下语境中：
        \(snippet)

        场景：\(scene.rawValue)
        """

        let raw = try await callClaude(system: systemPrompt, user: userMessage, maxTokens: 512)

        struct RawExplanation: Decodable {
            let chinese_explanation: String
            let example_sentence: String
            let example_sentence_chinese: String
            let scene_note: String
        }

        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let result = try? JSONDecoder().decode(RawExplanation.self, from: data) else {
            throw ClaudeAPIError.decodingError(raw)
        }

        return WordExplanation(
            chineseExplanation: result.chinese_explanation,
            exampleSentence: result.example_sentence,
            exampleSentenceChinese: result.example_sentence_chinese,
            sceneNote: result.scene_note
        )
    }

    // MARK: - 底层 HTTP 调用

    private func callClaude(system: String, user: String, maxTokens: Int) async throws -> String {
        let apiKey = APIConfig.claudeAPIKey
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [ClaudeMessage(role: "user", content: user)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            break
        case 401:
            throw ClaudeAPIError.unauthorized
        case 429:
            throw ClaudeAPIError.rateLimited
        default:
            let msg = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ClaudeAPIError.apiError(statusCode: http.statusCode, message: msg)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - 工具方法

    /// 去除 Claude 偶尔返回的 ```json ... ``` 包裹
    private func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") { s = String(s.dropFirst(7)) }
        else if s.hasPrefix("```")  { s = String(s.dropFirst(3)) }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 提取词汇在原文中的上下文片段（前后各 60 字符）
    private func contextSnippet(for word: String, in text: String) -> String {
        let lower = text.lowercased()
        let target = word.lowercased()
        guard let range = lower.range(of: target) else { return text.prefix(200).description }

        let start = text.index(range.lowerBound, offsetBy: -60, limitedBy: text.startIndex) ?? text.startIndex
        let end   = text.index(range.upperBound,  offsetBy:  60, limitedBy: text.endIndex)   ?? text.endIndex
        return String(text[start..<end])
    }
}

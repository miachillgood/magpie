//
//  ClaudeAPIService.swift
//  SnapLingo
//

import Foundation

// MARK: - 业务数据结构

struct SceneExtraction: Sendable {
    var scene: SceneType
    var title: String
    var candidates: [WordCandidate]
}

/// 要解释的一个词
struct ExplainItem: Sendable {
    var key: String
    var word: String
    var context: String
}

struct WordExplanation: Sendable {
    var lemma: String
    var partOfSpeech: String
    var cefr: CEFRLevel?
    var gloss: String
    var phonetic: String
    var explanation: String
    var exampleSentence: String
    var exampleTranslation: String
    var sceneNote: String
}

// MARK: - 错误

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case unauthorized
    case rateLimited
    case overloaded
    case network(Error)
    case decoding
    case truncated
    case api(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:     "还没有配置 Claude API Key"
        case .unauthorized: "API Key 无效，请检查配置"
        case .rateLimited:  "请求太频繁了，稍等一下再试"
        case .overloaded:   "服务有点忙，稍后再试"
        case .network:      "网络连接失败，请检查网络"
        case .decoding:     "返回的数据看不懂，请重试"
        case .truncated:    "内容太长被截断了，请重试"
        case .api(let code, _): "服务出错了（\(code)）"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .overloaded, .network: true
        case .api(let code, _): code >= 500
        default: false
        }
    }
}

// MARK: - ClaudeAPIService

/// 调用 Claude Messages API，用结构化输出（JSON Schema）保证返回格式
final class ClaudeAPIService: Sendable {
    static let shared = ClaudeAPIService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    /// 扫描流程对速度敏感，用 Haiku
    private let model = "claude-haiku-4-5"
    private let maxAttempts = 3

    // MARK: 1. 从场景文字里挑词

    func extractWords(from text: String, level: CEFRLevel) async throws -> SceneExtraction {
        let sceneList = SceneType.allCases
            .map { "- \($0.rawValue)：\($0.promptHint)" }
            .joined(separator: "\n")

        let system = """
        你是一位帮助中文母语者在英语国家生活的英语老师。用户拍下了生活中的英文文字，你要从中挑出值得学的单词。

        用户当前水平：CEFR \(level.code)（\(level.displayName)）。

        挑词规则：
        1. 挑 12–20 个对理解这个场景有用的实用词，覆盖从 \(level.code) 往上两级的难度，也可以保留少量更简单的词。
        2. 排除人名、品牌名、纯数字、单个字母、明显的 OCR 错误。
        3. 同一个词只出现一次；词组（如 "gluten free"）可以作为一个条目。
        4. word 是原文里的写法，lemma 是词典原形（小写，名词单数、动词原形）。
        5. cefr 是这个词义在日常英语里的大致等级。
        6. gloss 是结合这个场景的简短中文释义，不超过 8 个字。
        7. part_of_speech 用英文缩写：n. / v. / adj. / adv. / phr. 等。

        场景 scene 从下面选一个最贴切的：
        \(sceneList)

        title 是给这个场景起的简短中文标题（不超过 10 个字），尽量具体，比如“Countdown 超市货架”“租房合同”“咖啡店菜单”。
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["scene", "title", "words"],
            "properties": [
                "scene": ["type": "string", "enum": SceneType.allCases.map(\.rawValue)],
                "title": ["type": "string"],
                "words": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["word", "lemma", "part_of_speech", "cefr", "gloss"],
                        "properties": [
                            "word": ["type": "string"],
                            "lemma": ["type": "string"],
                            "part_of_speech": ["type": "string"],
                            "cefr": ["type": "string", "enum": CEFRLevel.allCases.map(\.code)],
                            "gloss": ["type": "string"]
                        ]
                    ]
                ]
            ]
        ]

        struct Raw: Decodable {
            struct Word: Decodable {
                let word: String
                let lemma: String
                let part_of_speech: String
                let cefr: String
                let gloss: String
            }
            let scene: String
            let title: String
            let words: [Word]
        }

        let raw: Raw = try await callJSON(
            system: system,
            user: "场景里识别出的英文文字：\n\n\(text.prefix(6000))",
            schema: schema,
            maxTokens: 3000
        )

        var seen = Set<String>()
        let candidates = raw.words.compactMap { word -> WordCandidate? in
            let candidate = WordCandidate(
                word: word.word,
                lemma: word.lemma.isEmpty ? word.word.lowercased() : word.lemma,
                partOfSpeech: word.part_of_speech,
                cefrRaw: CEFRLevel(code: word.cefr)?.rawValue ?? 0,
                gloss: word.gloss
            )
            guard !candidate.key.isEmpty, candidate.key.count > 1, seen.insert(candidate.key).inserted else { return nil }
            return candidate
        }
        return SceneExtraction(scene: SceneType(key: raw.scene), title: raw.title, candidates: candidates)
    }

    // MARK: 2. 批量生成解释

    /// 一次请求解释多个词；返回以 key 为索引的结果
    func explainWords(_ items: [ExplainItem], scene: SceneType) async throws -> [String: WordExplanation] {
        guard !items.isEmpty else { return [:] }

        let system = """
        你是一位帮助中文母语者在英语国家生活的英语老师。请为每个单词写一张简洁实用的学习卡片。

        要求：
        - explanation：结合所给语境的中文解释，不超过 30 个字，避免语法术语。
        - example_sentence：一个在\(scene.displayName)场景里真实会用到的英文例句，不超过 15 个词。
        - example_translation：例句的中文翻译。
        - scene_note：在国外生活时和这个词有关的实用提示（例如常见搭配、容易误解的地方、当地习惯），不超过 30 个字；没有就留空字符串。
        - phonetic：国际音标，例如 /ˈrɛnt/。
        - lemma、part_of_speech（n. / v. / adj. 等）、cefr（大致等级）、gloss（不超过 8 个字的简短释义）。
        - key 原样返回。
        """

        let list = items.enumerated().map { index, item in
            let context = item.context.isEmpty ? "" : "\n   语境：\(item.context.prefix(160))"
            return "\(index + 1). key=\(item.key) 单词：\(item.word)\(context)"
        }.joined(separator: "\n")

        let entrySchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["key", "lemma", "part_of_speech", "cefr", "gloss", "phonetic", "explanation", "example_sentence", "example_translation", "scene_note"],
            "properties": [
                "key": ["type": "string"],
                "lemma": ["type": "string"],
                "part_of_speech": ["type": "string"],
                "cefr": ["type": "string", "enum": CEFRLevel.allCases.map(\.code)],
                "gloss": ["type": "string"],
                "phonetic": ["type": "string"],
                "explanation": ["type": "string"],
                "example_sentence": ["type": "string"],
                "example_translation": ["type": "string"],
                "scene_note": ["type": "string"]
            ]
        ]
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["cards"],
            "properties": ["cards": ["type": "array", "items": entrySchema]]
        ]

        struct Raw: Decodable {
            struct Card: Decodable {
                let key: String
                let lemma: String
                let part_of_speech: String
                let cefr: String
                let gloss: String
                let phonetic: String
                let explanation: String
                let example_sentence: String
                let example_translation: String
                let scene_note: String
            }
            let cards: [Card]
        }

        let raw: Raw = try await callJSON(
            system: system,
            user: "场景：\(scene.displayName)\n\n需要解释的单词：\n\(list)",
            schema: schema,
            maxTokens: min(8000, 600 + items.count * 320)
        )

        var result: [String: WordExplanation] = [:]
        for card in raw.cards {
            result[card.key.normalizedWordKey] = WordExplanation(
                lemma: card.lemma,
                partOfSpeech: card.part_of_speech,
                cefr: CEFRLevel(code: card.cefr),
                gloss: card.gloss,
                phonetic: card.phonetic,
                explanation: card.explanation,
                exampleSentence: card.example_sentence,
                exampleTranslation: card.example_translation,
                sceneNote: card.scene_note
            )
        }
        return result
    }

    // MARK: - 底层调用

    private func callJSON<T: Decodable>(system: String, user: String, schema: [String: Any], maxTokens: Int) async throws -> T {
        let text = try await callWithRetry(system: system, user: user, schema: schema, maxTokens: maxTokens)
        guard let data = text.data(using: .utf8), let value = try? JSONDecoder().decode(T.self, from: data) else {
            throw ClaudeAPIError.decoding
        }
        return value
    }

    private func callWithRetry(system: String, user: String, schema: [String: Any], maxTokens: Int) async throws -> String {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await call(system: system, user: user, schema: schema, maxTokens: maxTokens)
            } catch let error as RetryableFailure {
                guard attempt < maxAttempts else { throw error.underlying }
                let backoff = error.retryAfter ?? pow(2, Double(attempt - 1)) + Double.random(in: 0...0.5)
                try await Task.sleep(for: .seconds(min(backoff, 10)))
            }
        }
    }

    private struct RetryableFailure: Error {
        let underlying: ClaudeAPIError
        let retryAfter: Double?
    }

    private func call(system: String, user: String, schema: [String: Any], maxTokens: Int) async throws -> String {
        let apiKey = APIConfig.claudeAPIKey
        guard !apiKey.isEmpty else { throw ClaudeAPIError.noAPIKey }

        var request = URLRequest(url: endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": ["format": ["type": "json_schema", "schema": schema]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RetryableFailure(underlying: .network(error), retryAfter: nil)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RetryableFailure(underlying: .network(URLError(.badServerResponse)), retryAfter: nil)
        }
        let retryAfter = http.value(forHTTPHeaderField: "retry-after").flatMap(Double.init)

        switch http.statusCode {
        case 200: break
        case 401, 403: throw ClaudeAPIError.unauthorized
        case 429: throw RetryableFailure(underlying: .rateLimited, retryAfter: retryAfter)
        case 529: throw RetryableFailure(underlying: .overloaded, retryAfter: retryAfter)
        case 500...599:
            throw RetryableFailure(underlying: .api(statusCode: http.statusCode, message: ""), retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeAPIError.api(statusCode: http.statusCode, message: message)
        }

        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ClaudeAPIError.decoding
        }
        if decoded.stop_reason == "max_tokens" { throw ClaudeAPIError.truncated }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeAPIError.decoding
        }
        return text
    }
}

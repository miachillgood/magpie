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
        case .noAPIKey:     String(localized: "还没有配置 Claude API Key")
        case .unauthorized: String(localized: "API Key 无效，请检查配置")
        case .rateLimited:  String(localized: "请求太频繁了，稍等一下再试")
        case .overloaded:   String(localized: "服务有点忙，稍后再试")
        case .network:      String(localized: "网络连接失败，请检查网络")
        case .decoding:     String(localized: "返回的数据看不懂，请重试")
        case .truncated:    String(localized: "内容太长被截断了，请重试")
        case .api(let code, _): String(localized: "服务出错了（\(code)）")
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

    func extractWords(from text: String, level: CEFRLevel, language: NativeLanguage) async throws -> SceneExtraction {
        let sceneList = SceneType.allCases
            .map { "- \($0.rawValue): \($0.promptHint)" }
            .joined(separator: "\n")
        let native = language.promptName

        let system = """
        You are an English teacher helping people whose native language is \(native) live in an English-speaking country. \
        The user photographed English text from daily life; pick the words worth learning from it.

        The user's current level: CEFR \(level.code).

        Rules for picking words:
        1. Pick 12–20 practical words that help understand this scene, ranging from \(level.code) up to two levels above; a few easier words are fine.
        2. Exclude personal names, brand names, bare numbers, single letters and obvious OCR errors.
        3. Each word appears once; a phrase (e.g. "gluten free") may be one entry.
        4. `word` is the spelling in the text; `lemma` is the dictionary form (lowercase, singular noun, base verb).
        5. `cefr` is the rough level of this sense in everyday English.
        6. `gloss` is a short meaning in \(native) that fits this scene, \(language.lengthLimit(characters: 8, words: 4)).
        7. `part_of_speech` uses English abbreviations: n. / v. / adj. / adv. / phr. etc.

        Pick the one `scene` that fits best:
        \(sceneList)

        `title` is a short, specific title for this scene in \(native) (\(language.lengthLimit(characters: 10, words: 5))). \
        Keep shop or brand names in their original spelling, e.g. "Countdown" + a word for supermarket shelf, or a word for rental contract, or "Little Bird" + a word for café menu.
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
            user: "English text recognized in the scene:\n\n\(text.prefix(6000))",
            schema: schema,
            maxTokens: language.usesCharacterCount ? 3000 : 3600
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
    func explainWords(_ items: [ExplainItem], scene: SceneType, language: NativeLanguage) async throws -> [String: WordExplanation] {
        guard !items.isEmpty else { return [:] }
        let native = language.promptName

        let system = """
        You are an English teacher helping people whose native language is \(native) live in an English-speaking country. \
        Write a short, practical study card for each word. Write every explanatory field in \(native).

        Fields:
        - explanation: what the word means in the given context, in \(native), \(language.lengthLimit(characters: 30, words: 20)), no grammar jargon.
        - example_sentence: one natural English sentence someone would really hear or read in a \(scene.promptName) setting, at most 15 words.
        - example_translation: the \(native) translation of that example sentence.
        - scene_note: one practical tip in \(native) for living abroad related to this word (common collocations, easy misunderstandings, local customs), \(language.lengthLimit(characters: 30, words: 20)); use an empty string if there is nothing useful.
        - phonetic: IPA, e.g. /ˈrɛnt/.
        - lemma, part_of_speech (n. / v. / adj. etc.), cefr (rough level), gloss (a short meaning in \(native), \(language.lengthLimit(characters: 8, words: 4))).
        - key: copy the quoted key exactly, without the quotes.
        """

        let list = items.enumerated().map { index, item in
            // 值都加引号，模型才不会把后面的 word 当成 key 的一部分
            let context = item.context.isEmpty ? "" : "\n   context: \"\(item.context.prefix(160))\""
            return "\(index + 1). key: \"\(item.key)\", word: \"\(item.word)\"\(context)"
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
            user: "Scene: \(scene.promptName)\n\nWords to explain:\n\(list)",
            schema: schema,
            // 拉丁文字的释义比中日韩长，预算给多一点，避免被截断
            maxTokens: min(8000, 600 + items.count * (language.usesCharacterCount ? 320 : 420))
        )

        var result: [String: WordExplanation] = [:]
        let requested = items.map(\.key)
        for card in raw.cards {
            result[Self.matchKey(card.key, lemma: card.lemma, requested: requested)] = WordExplanation(
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

    /// 模型偶尔会把 key 改写一点（多带一个词、换成原形），尽量对回我们发出去的 key
    nonisolated static func matchKey(_ returned: String, lemma: String, requested: [String]) -> String {
        let key = returned.normalizedWordKey
        if requested.contains(key) { return key }
        let lemmaKey = lemma.normalizedWordKey
        if requested.contains(lemmaKey) { return lemmaKey }
        // 最长的前缀匹配：“bond word” → “bond”
        if let prefix = requested.filter({ key.hasPrefix($0 + " ") }).max(by: { $0.count < $1.count }) { return prefix }
        return key
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

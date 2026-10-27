//
//  ClaudeAPIService.swift
//  SnapLingo
//

import Foundation

// MARK: - 业务数据结构

struct SceneExtraction: Sendable {
    var scene: SceneType
    /// 场景标题：店名（如果有）+ 场景名词，界面语言，比如「Little Bird 咖啡菜单」/「Little Bird café menu」
    var title: String
    var candidates: [WordCandidate]
    /// 照片上认出的店名或品牌，原拼写；没有就是空的。首页把它放进胶囊
    var place: String = ""

    /// 店名 + 场景名词拼成标题；店名已经在名词里了就不重复
    static func title(place: String, noun: String) -> String {
        let place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let noun = noun.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else { return noun }
        guard !noun.isEmpty else { return place }
        if noun.localizedCaseInsensitiveContains(place) { return noun }
        return "\(place) \(noun)"
    }
}

/// 「说一说」听到的是什么
enum SpeechIntent: Sendable {
    /// 念了一个英文词（或「燕麦英语怎么说」）：直接查这个词
    case word(String)
    /// 描述了一个场景：推荐这个场景要用的词
    case scene(SceneExtraction)

    /// AI 判断错了也尽量给个能用的结果：说是词却没给词、说是场景却没挑出词时，英语那条像个词就当查词
    nonisolated static func resolve(kind: String, word: String, english: String, extraction: SceneExtraction) -> SpeechIntent? {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let english = english.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if kind == "word", WordLookupSheet.isLookupQuery(word) { return .word(word) }
        if !extraction.candidates.isEmpty, kind == "scene" || !WordLookupSheet.isLookupQuery(english) {
            return .scene(extraction)
        }
        if WordLookupSheet.isLookupQuery(english) { return .word(english) }
        return extraction.candidates.isEmpty ? nil : .scene(extraction)
    }
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
    /// 用户没同意把文字发给 AI
    case aiDisabled
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
        case .aiDisabled:   String(localized: "AI 功能已关闭，可以在“我的”里打开", comment: "Shown when the user has not allowed sending text to AI. No final period: it is inserted into a longer sentence")
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
        // 标题显示在界面里，跟界面语言走（释义才用母语）
        let interface = NativeLanguage(preferredLanguages: Bundle.main.preferredLocalizations)

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

        `place` is the shop, brand or venue name shown in the text, in its original spelling (e.g. "Countdown", "Little Bird", "AT HOP"); \
        use an empty string if there is none. Never invent one.
        `title` is a short noun for what was photographed, in \(interface.promptName) (\(interface.lengthLimit(characters: 6, words: 3))), \
        without the place name, e.g. café menu, supermarket shelf, bus stop sign, rental listing.
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["scene", "place", "title", "words"],
            "properties": [
                "scene": ["type": "string", "enum": SceneType.allCases.map(\.rawValue)],
                "place": ["type": "string"],
                "title": ["type": "string"],
                "words": Self.wordListSchema
            ]
        ]

        struct Raw: Decodable {
            let scene: String
            let place: String
            let title: String
            let words: [RawWord]
        }

        let raw: Raw = try await callJSON(
            system: system,
            user: "English text recognized in the scene:\n\n\(text.prefix(6000))",
            schema: schema,
            maxTokens: language.usesCharacterCount ? 3000 : 3600
        )

        let place = raw.place.trimmingCharacters(in: .whitespacesAndNewlines)
        return SceneExtraction(
            scene: SceneType(key: raw.scene),
            title: SceneExtraction.title(place: place, noun: raw.title),
            candidates: Self.candidates(from: raw.words),
            place: place
        )
    }

    /// 挑词结果里的一个词（拍照和说一说共用）
    private struct RawWord: Decodable {
        let word: String
        let lemma: String
        let part_of_speech: String
        let cefr: String
        let gloss: String
    }

    private static let wordListSchema: [String: Any] = [
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

    /// 去重、去掉单个字母
    private static func candidates(from words: [RawWord]) -> [WordCandidate] {
        var seen = Set<String>()
        return words.compactMap { word -> WordCandidate? in
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
    }

    // MARK: 1b. 说一说：判断是查词还是描述场景

    /// english / native 是同一段录音分别按英语和母语识别出来的文字
    func interpretSpeech(english: String, native: String, level: CEFRLevel, language: NativeLanguage) async throws -> SpeechIntent? {
        let sceneList = SceneType.allCases
            .map { "- \($0.rawValue): \($0.promptHint)" }
            .joined(separator: "\n")
        let nativeName = language.promptName
        let interface = NativeLanguage(preferredLanguages: Bundle.main.preferredLocalizations)

        let system = """
        You are an English teacher helping people whose native language is \(nativeName) live in an English-speaking country. \
        The user just spoke to the app. The same recording was transcribed twice, once as English and once as \(nativeName); \
        the transcript in the wrong language is usually garbled, so trust the one that makes sense.

        Decide what the user wants:
        - kind "word": they said one English word or short phrase they want to look up, or asked how to say something in English \
        (e.g. "oat milk", "怎么说燕麦"). Put the English word or phrase in `word` (dictionary form, lowercase). Leave `words` empty.
        - kind "scene": they described a situation, plan or place in daily life (e.g. "明天要去看牙医", "I need to open a bank account"). \
        Leave `word` empty and pick 8–15 practical English words or phrases they will likely hear, read or need to say there.

        The user's current level: CEFR \(level.code). For "scene" words:
        1. Range from \(level.code) up to two levels above; a few easier words are fine.
        2. `word` and `lemma` are the dictionary form (lowercase, singular noun, base verb); a phrase may be one entry.
        3. `cefr` is the rough level of this sense in everyday English.
        4. `gloss` is a short meaning in \(nativeName) that fits this scene, \(language.lengthLimit(characters: 8, words: 4)).
        5. `part_of_speech` uses English abbreviations: n. / v. / adj. / adv. / phr. etc.

        Pick the one `scene` that fits best (use general for "word"):
        \(sceneList)

        `place` is a shop, brand or venue the user named, in its original spelling; use an empty string if none. Never invent one.
        `title` is a short noun for the situation, in \(interface.promptName) (\(interface.lengthLimit(characters: 6, words: 3))), \
        without the place name, e.g. dentist visit, opening a bank account, flat viewing. Empty for "word".
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["kind", "word", "scene", "place", "title", "words"],
            "properties": [
                "kind": ["type": "string", "enum": ["word", "scene"]],
                "word": ["type": "string"],
                "scene": ["type": "string", "enum": SceneType.allCases.map(\.rawValue)],
                "place": ["type": "string"],
                "title": ["type": "string"],
                "words": Self.wordListSchema
            ]
        ]

        struct Raw: Decodable {
            let kind: String
            let word: String
            let scene: String
            let place: String
            let title: String
            let words: [RawWord]
        }

        let raw: Raw = try await callJSON(
            system: system,
            user: "English transcript: \"\(english.prefix(1000))\"\n\(nativeName) transcript: \"\(native.prefix(1000))\"",
            schema: schema,
            maxTokens: language.usesCharacterCount ? 2400 : 3000
        )

        let place = raw.place.trimmingCharacters(in: .whitespacesAndNewlines)
        let extraction = SceneExtraction(
            scene: SceneType(key: raw.scene),
            title: SceneExtraction.title(place: place, noun: raw.title),
            candidates: Self.candidates(from: raw.words),
            place: place
        )
        return SpeechIntent.resolve(kind: raw.kind, word: raw.word, english: english, extraction: extraction)
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
        // 所有请求都从这里出去：没同意就一个字都不发
        guard AIConsent.isGranted else { throw ClaudeAPIError.aiDisabled }
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

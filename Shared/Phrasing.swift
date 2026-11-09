//
//  Phrasing.swift
//  Shared（iPhone 和 Apple Watch 都编译这个文件）
//
//  「这句话英语怎么说」：用户用任何语言说想表达的意思（「我想跟店员说少放点冰」），
//  AI 给 2–3 种地道说法（随意 / 一般 / 礼貌），带母语翻译和一句用法提示。
//  手机上走「说一说」（ClaudeAPIService.interpretSpeech 里的 kind = say），
//  手表上直接联网问（PhrasingClient），两边用同一份提示词和数据格式。
//

import Foundation

/// 一种说法
nonisolated struct Phrasing: Codable, Hashable, Identifiable, Sendable {
    enum Tone: String, Codable, Sendable, CaseIterable {
        case casual, neutral, polite
    }

    var text: String
    var tone: Tone
    /// 母语翻译
    var translation: String
    /// 什么时候用、要注意什么（母语，可以为空）
    var note: String

    var id: String { text }
}

/// 一次「怎么说」的结果
nonisolated struct PhrasingResult: Codable, Hashable, Sendable {
    /// 想表达的意思，母语短标题，比如「少放点冰」
    var situation: String
    var phrasings: [Phrasing]
}

nonisolated enum PhrasingPrompt {
    /// 写进 system prompt 的规则；nativeName 是母语的英文名（Simplified Chinese 等）
    static func rules(nativeName: String) -> String {
        """
        Give 2–3 natural ways a local would actually say it in everyday English (New Zealand / Australia / UK / US neutral), \
        from casual to polite. Each `text` is one short spoken sentence (at most 15 words), no quotes. \
        `tone` is casual, neutral or polite. `translation` is that sentence translated into \(nativeName) — \
        never repeat the English. \
        `note` is an optional short tip in \(nativeName) (when to use it, what to avoid), at most 20 characters or 12 words; \
        use an empty string if there is nothing useful. \
        `situation` is a very short title in \(nativeName) for what the user wants to say, e.g. 少放点冰.
        """
    }

    static let phrasingSchema: [String: Any] = [
        "type": "array",
        "items": [
            "type": "object",
            "additionalProperties": false,
            "required": ["text", "tone", "translation", "note"],
            "properties": [
                "text": ["type": "string"],
                "tone": ["type": "string", "enum": Phrasing.Tone.allCases.map(\.rawValue)],
                "translation": ["type": "string"],
                "note": ["type": "string"]
            ]
        ]
    ]

    /// 去掉空的和重复的，最多 3 条
    static func clean(_ phrasings: [Phrasing]) -> [Phrasing] {
        var seen = Set<String>()
        return phrasings
            .map { var p = $0; p.text = p.text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))); return p }
            .filter { !$0.text.isEmpty && seen.insert($0.text.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }
}

/// 手表上直接问 Claude（手机上走 ClaudeAPIService，那边有重试和统一的同意检查）
nonisolated enum PhrasingClient {
    enum Failure: Error {
        case noAPIKey, network, server(Int), decoding
    }

    static func suggest(for request: String, nativeName: String, apiKey: String) async throws -> PhrasingResult {
        guard !apiKey.isEmpty else { throw Failure.noAPIKey }
        let system = """
        You are an English teacher helping people whose native language is \(nativeName) live in an English-speaking country. \
        The user tells you, in any language, something they want to say in English.
        \(PhrasingPrompt.rules(nativeName: nativeName))
        """
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["situation", "phrasings"],
            "properties": [
                "situation": ["type": "string"],
                "phrasings": PhrasingPrompt.phrasingSchema
            ]
        ]
        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1200,
            "system": system,
            "messages": [["role": "user", "content": "What I want to say: \(request.prefix(500))"]],
            "output_config": ["format": ["type": "json_schema", "schema": schema]]
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 30)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Failure.network
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw Failure.server(http.statusCode) }

        struct Envelope: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let text = envelope.content.first(where: { $0.type == "text" })?.text,
              let json = text.data(using: .utf8),
              var result = try? JSONDecoder().decode(PhrasingResult.self, from: json)
        else { throw Failure.decoding }
        result.phrasings = PhrasingPrompt.clean(result.phrasings)
        guard !result.phrasings.isEmpty else { throw Failure.decoding }
        return result
    }
}

//
//  Scan.swift
//  SnapLingo
//

import Foundation
import CoreGraphics
import SwiftData

// MARK: - OCR 单词框

/// 照片上识别出的一个英文单词。rect 为归一化坐标（0...1，左上角为原点）
nonisolated struct OCRToken: Codable, Hashable, Sendable, Identifiable {
    var id: Int
    var text: String
    var rect: CGRect
    var lineIndex: Int

    var key: String { text.normalizedWordKey }
}

/// OCR 识别出的一行文字，用来给单词提供上下文
nonisolated struct OCRLine: Codable, Hashable, Sendable {
    var text: String
    var rect: CGRect
}

// MARK: - 候选词

/// Claude 从场景文字里挑出的候选词（或用户在照片上点选的词）
struct WordCandidate: Codable, Hashable, Sendable, Identifiable {
    var word: String
    var lemma: String
    var partOfSpeech: String
    /// 1...6 对应 A1...C2；0 表示未知
    var cefrRaw: Int
    var gloss: String
    var pickedFromPhoto: Bool = false

    var id: String { key }
    var key: String { lemma.isEmpty ? word.normalizedWordKey : lemma.normalizedWordKey }
    var cefr: CEFRLevel? { CEFRLevel(rawValue: cefrRaw) }
    var displayWord: String { lemma.isEmpty ? word : lemma }
}

// MARK: - Scan（场景）

/// 一次扫描：原图 + 识别出的文字 + 从中保存的单词
@Model
final class Scan {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String = ""
    /// 照片上认出的店名（原拼写），首页放进胶囊；空 = 没认出来，或者是旧数据
    var placeName: String = ""
    /// 拍照时在哪个街区（Ponsonby），只有相机拍的、用户允许定位时才有
    var neighborhood: String = ""
    var latitude: Double?
    var longitude: Double?
    var sceneRaw: String = SceneType.general.rawValue

    /// 原图（最长边 2048，JPEG）
    @Attribute(.externalStorage) var imageData: Data?
    /// 列表用缩略图（最长边 600）
    @Attribute(.externalStorage) var thumbnailData: Data?
    /// 宽 / 高
    var imageAspectRatio: Double = 1

    var ocrText: String = ""
    var tokensData: Data?
    var linesData: Data?
    var candidatesData: Data?

    @Relationship(deleteRule: .nullify, inverse: \VocabWord.scans)
    var words: [VocabWord] = []

    init(createdAt: Date = Date()) {
        self.id = UUID()
        self.createdAt = createdAt
    }

    var scene: SceneType {
        get { SceneType(key: sceneRaw) }
        set { sceneRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? scene.displayName : trimmed
    }

    var tokens: [OCRToken] {
        get { Scan.decode(tokensData) ?? [] }
        set { tokensData = Scan.encode(newValue) }
    }

    var lines: [OCRLine] {
        get { Scan.decode(linesData) ?? [] }
        set { linesData = Scan.encode(newValue) }
    }

    var candidates: [WordCandidate] {
        get { Scan.decode(candidatesData) ?? [] }
        set { candidatesData = Scan.encode(newValue) }
    }

    /// 包含该词的那一行文字，作为语境
    func contextLine(for key: String) -> String {
        lines.first { line in
            line.text.wordKeys.contains(key)
        }?.text ?? ""
    }

    private static func decode<T: Decodable>(_ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
}

// MARK: - 单词规范化

nonisolated extension String {
    /// 去重用的 key：小写、去首尾空白和标点
    var normalizedWordKey: String {
        lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            .replacingOccurrences(of: "’", with: "'")
    }

    /// 这一段文字中所有单词的 key
    var wordKeys: Set<String> {
        var keys = Set<String>()
        enumerateSubstrings(in: startIndex..<endIndex, options: .byWords) { word, _, _, _ in
            if let word { keys.insert(word.normalizedWordKey) }
        }
        return keys
    }
}

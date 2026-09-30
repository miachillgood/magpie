//
//  WordExport.swift
//  SnapLingo
//
//  把词库导出成表格文件（CSV，UTF-8 带 BOM，Excel / Numbers / Anki 都能直接打开）。
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 导出的一行
nonisolated struct ExportRow: Sendable {
    var word: String
    var partOfSpeech: String
    var meaning: String
    var example: String
    var exampleTranslation: String
    var scene: String
    var addedAt: Date
}

enum WordExport {
    nonisolated static let header = ["word", "part_of_speech", "meaning", "example", "example_translation", "scene", "added"]

    /// 生成 CSV 文本（RFC 4180：含逗号、引号、换行的字段用双引号包起来，引号写两遍）
    nonisolated static func csv(_ rows: [ExportRow], timeZone: TimeZone = .current) -> String {
        // 按用户所在时区写日期，不然新西兰早上存的词会记成前一天
        let dateFormat = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
        var lines = [header.map(escape).joined(separator: ",")]
        for row in rows {
            let fields = [row.word, row.partOfSpeech, row.meaning, row.example, row.exampleTranslation, row.scene, row.addedAt.formatted(dateFormat)]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    nonisolated static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func rows(from words: [VocabWord]) -> [ExportRow] {
        words.sorted { $0.addedAt < $1.addedAt }.map { word in
            ExportRow(
                word: word.word,
                partOfSpeech: word.partOfSpeech,
                meaning: word.meaning,
                example: word.exampleSentence,
                exampleTranslation: word.exampleTranslation,
                scene: word.latestScan?.displayTitle ?? "",
                addedAt: word.addedAt
            )
        }
    }
}

/// 给 ShareLink 用：分享时才生成临时文件
struct WordExportFile: Transferable {
    var rows: [ExportRow]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appending(path: "Magpie-words.csv")
            // 带 BOM，Excel 才能正确识别 UTF-8 里的中日韩文字
            let data = Data([0xEF, 0xBB, 0xBF]) + Data(WordExport.csv(file.rows).utf8)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

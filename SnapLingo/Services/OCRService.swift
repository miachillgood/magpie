//
//  OCRService.swift
//  SnapLingo
//

import CoreGraphics
import Foundation
import Vision

nonisolated struct OCRResult: Sendable {
    var fullText: String
    var lines: [OCRLine]
    var tokens: [OCRToken]
}

nonisolated enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: String(localized: "图片处理失败，请换一张试试")
        case .noTextFound:           String(localized: "没有找到英文文字。靠近一点、保持光线充足再拍一次吧")
        case .failed:                String(localized: "文字识别失败，请重试")
        }
    }
}

/// 用 Vision 识别英文，输出整段文字、每一行、以及每个单词在照片上的位置
nonisolated enum OCRService {

    @concurrent
    static func recognize(_ cgImage: CGImage) async throws -> OCRResult {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.usesLanguageCorrection = true

        let observations: [RecognizedTextObservation]
        do {
            observations = try await request.perform(on: cgImage)
        } catch {
            throw OCRError.failed(error)
        }

        var lines: [OCRLine] = []
        var tokens: [OCRToken] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            guard text.contains(where: \.isLetter) else { continue }

            let lineIndex = lines.count
            lines.append(OCRLine(text: text, rect: observation.boundingBox.verticallyFlipped().cgRect))

            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, _, _ in
                guard let word, word.count > 1, word.contains(where: \.isLetter),
                      !word.allSatisfy({ $0.isNumber || $0.isPunctuation }) else { return }
                guard let box = candidate.boundingBox(for: range) else { return }
                tokens.append(OCRToken(
                    id: tokens.count,
                    text: word,
                    rect: box.boundingBox.verticallyFlipped().cgRect,
                    lineIndex: lineIndex
                ))
            }
        }

        let fullText = lines.map(\.text).joined(separator: "\n")
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextFound
        }
        return OCRResult(fullText: fullText, lines: lines, tokens: tokens)
    }
}

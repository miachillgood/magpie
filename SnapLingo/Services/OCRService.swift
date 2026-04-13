//
//  OCRService.swift
//  SnapLingo
//

import UIKit
import Vision

// MARK: - 结果类型

struct OCRResult {
    let fullText: String          // 所有文字块拼接（换行分隔）
    let textBlocks: [TextBlock]   // 各文字块详情
}

struct TextBlock {
    let text: String
    let confidence: Float
    let boundingBox: CGRect       // Vision 坐标系（左下原点，归一化）
}

// MARK: - 错误类型

enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case visionRequestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "图片格式转换失败，请重试"
        case .noTextFound:           return "未识别到任何文字，请确保照片中有清晰的英文内容"
        case .visionRequestFailed(let e): return "文字识别失败：\(e.localizedDescription)"
        }
    }
}

// MARK: - OCRService

final class OCRService {

    /// 识别图片中的英文文字
    /// - 在后台线程执行，不阻塞 MainActor
    func recognizeText(in image: UIImage) async throws -> OCRResult {
        // 先做尺寸预处理
        let processed = ImageUtilities.prepareForOCR(image)

        guard let cgImage = processed.cgImage else {
            throw OCRError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.visionRequestFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                var blocks: [TextBlock] = []
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    blocks.append(TextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: obs.boundingBox
                    ))
                }

                let fullText = blocks.map(\.text).joined(separator: "\n")
                if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: OCRResult(fullText: fullText, textBlocks: blocks))
                }
            }

            // 配置：高精度英文识别
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionRequestFailed(error))
            }
        }
    }
}

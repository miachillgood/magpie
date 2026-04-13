//
//  CameraViewModel.swift
//  SnapLingo
//

import SwiftUI

@Observable
final class CameraViewModel {

    // MARK: - 状态

    var capturedImage: UIImage?
    var ocrResult: OCRResult?
    var isProcessing = false
    var errorMessage: String?
    var navigateToWordSelection = false

    // MARK: - 依赖

    private let ocrService = OCRService()

    // MARK: - 动作

    /// 用户选好图片后调用：执行 OCR，成功后推进到词汇筛选页
    func processImage(_ image: UIImage) async {
        await MainActor.run {
            capturedImage = image
            isProcessing = true
            errorMessage = nil
            ocrResult = nil
            navigateToWordSelection = false
        }

        do {
            let result = try await ocrService.recognizeText(in: image)
            await MainActor.run {
                ocrResult = result
                isProcessing = false
                navigateToWordSelection = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    /// 重置状态（返回相机页时调用）
    func reset() {
        capturedImage = nil
        ocrResult = nil
        isProcessing = false
        errorMessage = nil
        navigateToWordSelection = false
    }
}

//
//  ScanFlowView.swift
//  SnapLingo
//

import SwiftUI
import SwiftData

/// 扫描流程：拍照 → 识别 → 选词
struct ScanFlowView: View {
    private enum Stage {
        case capture
        case processing(UIImage)
        case picking(WordLibrary.ScanDraft)
    }

    @State private var stage: Stage = .capture
    /// 第一次拍照、还没决定要不要用 AI：先弹窗问，选完再处理这张照片
    @State private var awaitingConsent: UIImage?
    #if DEBUG
    @Query(sort: \Scan.createdAt, order: .reverse) private var previewScans: [Scan]
    private var previewScan: Scan? { previewScans.first }
    #endif

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture:
                    ScanCameraView { image in
                        if AIConsent.state == .undecided {
                            awaitingConsent = image
                        } else {
                            withAnimation(.smooth) { stage = .processing(image) }
                        }
                    }
                case .processing(let image):
                    ScanProcessingView(image: image) { draft in
                        withAnimation(.smooth) { stage = .picking(draft) }
                    } onRetake: {
                        withAnimation(.smooth) { stage = .capture }
                    }
                case .picking(let draft):
                    WordPickerView(draft: draft) {
                        withAnimation(.smooth) { stage = .capture }
                    }
                }
            }
            .transition(.opacity)
        }
        #if DEBUG
        // 截图用：-previewAIConsent 直接弹出 AI 说明
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-previewAIConsent") { awaitingConsent = UIImage() }
            // -previewPicker：用最近一张照片假装刚拍完，直接打开选词页（模拟器没有相机，也不用调 AI）
            if ProcessInfo.processInfo.arguments.contains("-previewPicker"), let scan = previewScan, let image = scan.fullImage {
                let draft = WordLibrary.ScanDraft(
                    image: image,
                    ocr: OCRResult(fullText: scan.ocrText, lines: scan.lines, tokens: scan.tokens),
                    extraction: SceneExtraction(scene: scan.scene, title: scan.displayTitle, candidates: scan.candidates)
                )
                stage = .picking(draft)
            }
        }
        #endif
        .sheet(isPresented: Binding(get: { awaitingConsent != nil }, set: { _ in })) {
            AIConsentSheet {
                guard let image = awaitingConsent else { return }
                awaitingConsent = nil
                withAnimation(.smooth) { stage = .processing(image) }
            }
        }
    }
}

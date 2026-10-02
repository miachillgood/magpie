//
//  ScanFlowView.swift
//  SnapLingo
//

import SwiftUI

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

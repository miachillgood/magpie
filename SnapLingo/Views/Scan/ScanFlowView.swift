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

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .capture:
                    ScanCameraView { image in
                        withAnimation(.smooth) { stage = .processing(image) }
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
    }
}

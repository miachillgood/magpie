//
//  LoadingOverlayView.swift
//  SnapLingo
//

import SwiftUI

struct LoadingOverlayView: View {
    var message: String = "处理中…"

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                    .tint(.white)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

#Preview {
    LoadingOverlayView(message: "正在识别文字…")
}

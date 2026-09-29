//
//  PhotoWordOverlay.swift
//  SnapLingo
//

import SwiftUI
import UIKit

/// 照片上单词框的样式
enum TokenHighlight: Equatable {
    /// 不显示，但可以点
    case none
    /// 候选词（虚线框）
    case candidate
    /// 已选中（品牌色填充）
    case selected
    /// 已在词库（绿色描边）
    case saved
}

/// 在照片上叠加可点击的单词框
struct PhotoWordOverlay: View {
    var image: UIImage
    var tokens: [OCRToken]
    var highlight: (OCRToken) -> TokenHighlight
    var onTap: ((OCRToken) -> Void)?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    let size = proxy.size
                    ForEach(tokens) { token in
                        let style = highlight(token)
                        let rect = CGRect(
                            x: token.rect.minX * size.width,
                            y: token.rect.minY * size.height,
                            width: token.rect.width * size.width,
                            height: token.rect.height * size.height
                        ).insetBy(dx: -3, dy: -2)

                        TokenBox(style: style)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .onTapGesture { onTap?(token) }
                            .allowsHitTesting(onTap != nil)
                            .accessibilityHidden(style == .none)
                            .accessibilityLabel(token.text)
                            .accessibilityAddTraits(style == .selected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
    }
}

private struct TokenBox: View {
    var style: TokenHighlight

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        switch style {
        case .none:
            shape.fill(Color.white.opacity(0.001))
        case .candidate:
            shape
                .fill(Color.white.opacity(0.12))
                .overlay(shape.strokeBorder(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
                .shadow(color: .black.opacity(0.35), radius: 1)
        case .selected:
            shape
                .fill(Theme.brand.opacity(0.35))
                .overlay(shape.strokeBorder(Theme.brand, lineWidth: 2))
        case .saved:
            shape
                .fill(Theme.success.opacity(0.2))
                .overlay(shape.strokeBorder(Theme.success, lineWidth: 1.5))
        }
    }
}

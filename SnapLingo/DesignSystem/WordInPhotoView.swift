//
//  WordInPhotoView.swift
//  SnapLingo
//

import SwiftUI
import UIKit

/// 把照片裁到这个词出现的位置，并框出这个词 —— “你是在这里见到它的”
struct WordInPhotoView: View {
    var word: VocabWord
    var scan: Scan
    /// 显示区域的宽高比（用于裁切）
    var aspectRatio: CGFloat = 1.7

    @State private var crop: Crop?
    @State private var resolved = false

    private struct Crop {
        var image: UIImage
        /// 单词框在裁切图里的归一化位置
        var highlight: CGRect
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let crop {
                    Image(uiImage: crop.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay {
                            highlightBox(crop, in: proxy.size)
                        }
                } else if resolved {
                    ScanThumbnail(scan: scan)
                } else {
                    Theme.insetFill
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: word.id) {
            crop = makeCrop()
            resolved = true
        }
    }

    private func highlightBox(_ crop: Crop, in size: CGSize) -> some View {
        let imageSize = crop.image.size
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let offsetX = (size.width - imageSize.width * scale) / 2
        let offsetY = (size.height - imageSize.height * scale) / 2
        let rect = CGRect(
            x: crop.highlight.minX * imageSize.width * scale + offsetX,
            y: crop.highlight.minY * imageSize.height * scale + offsetY,
            width: crop.highlight.width * imageSize.width * scale,
            height: crop.highlight.height * imageSize.height * scale
        ).insetBy(dx: -5, dy: -4)

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Theme.brand, lineWidth: 2.5)
            .background(Theme.brand.opacity(0.15), in: .rect(cornerRadius: 6, style: .continuous))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: .black.opacity(0.25), radius: 3)
    }

    // MARK: - 计算裁切区域

    private func makeCrop() -> Crop? {
        guard let target = tokenRect(), let image = scan.fullImage, let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // 单词框（像素）
        let box = CGRect(x: target.minX * width, y: target.minY * height, width: target.width * width, height: target.height * height)

        // 裁切区域：单词宽度的 2.5 倍，至少半张图宽，按显示比例
        var regionWidth = min(max(box.width * 2.5, width * 0.5), width)
        var regionHeight = regionWidth / aspectRatio
        if regionHeight > height {
            regionHeight = height
            regionWidth = min(regionHeight * aspectRatio, width)
        }
        var origin = CGPoint(x: box.midX - regionWidth / 2, y: box.midY - regionHeight / 2)
        origin.x = min(max(origin.x, 0), width - regionWidth)
        origin.y = min(max(origin.y, 0), height - regionHeight)
        let region = CGRect(origin: origin, size: CGSize(width: regionWidth, height: regionHeight)).integral

        guard let cropped = cgImage.cropping(to: region) else { return nil }
        let highlight = CGRect(
            x: (box.minX - region.minX) / region.width,
            y: (box.minY - region.minY) / region.height,
            width: box.width / region.width,
            height: box.height / region.height
        )
        return Crop(image: UIImage(cgImage: cropped), highlight: highlight)
    }

    /// 找到这个词（可能是词组）在照片上的位置，优先用保存时记录的那一行
    private func tokenRect() -> CGRect? {
        let tokens = scan.tokens
        guard !tokens.isEmpty else { return nil }
        let preferredLine = scan.lines.firstIndex { $0.text == word.contextSnippet }
        guard let group = TokenMatcher(tokens: tokens).occurrences(of: word.word, preferLine: preferredLine).first,
              let first = group.first else { return nil }
        return group.dropFirst().reduce(first.rect) { $0.union($1.rect) }
    }
}
